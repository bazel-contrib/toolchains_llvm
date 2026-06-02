#!/bin/bash
# Copyright 2021 The Bazel Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

scripts_dir="$(dirname "${BASH_SOURCE[0]}")"
source "${scripts_dir}/bazel.sh"
"${bazel}" version

cd "${scripts_dir}"

# Returns the path of the //:stdlib_test binary as built with the given
# configuration. The output path is configuration-specific (it depends on the
# target platform and flags), so we resolve it with cquery rather than assuming
# the default bazel-bin.
binpath_for() {
  "${bazel}" --bazelrc=/dev/null cquery "$@" --output=files //:stdlib_test 2>/dev/null
}

# Runs the cross-compiled binary inside a container for the matching platform.
# Skipped in CI because the macOS GitHub Action runners do not have docker.
check_with_image() {
  if "${CI:-false}"; then
    return
  fi
  local docker_platform="$1"
  local image="$2"
  local binpath="$3"
  docker run --rm -it --platform="${docker_platform}" \
    --mount "type=bind,source=${binpath},target=/stdlib_test" "${image}" /stdlib_test
}

# Cross-compiles //:stdlib_test for a target and verifies the produced binary is
# an ELF for the expected architecture, both with dynamically and statically
# linked system libraries.
#
# Args:
#   1: bazel target platform label
#   2: cc toolchain label for the sysroot toolchain
#   3: regex matched against `file` output to assert the ELF architecture
#   4: docker --platform value used to smoke-test the binary
xcompile_test() {
  local platform="$1"
  local toolchain="$2"
  local arch_regex="$3"
  local docker_platform="$4"

  local build_args=(
    "${common_args[@]}"
    --platforms="${platform}"
    --extra_toolchains="${toolchain}"
    --symlink_prefix=/
    --color=yes
    --show_progress_rate_limit=30
  )

  echo ""
  echo "Testing ${platform}: static linked user libraries and dynamic linked system libraries"
  "${bazel}" --bazelrc=/dev/null build "${build_args[@]}" //:stdlib_test
  local binpath
  binpath="$(binpath_for "${build_args[@]}")"
  file "${binpath}" | tee /dev/stderr | grep -qE "${arch_regex}"
  check_with_image "${docker_platform}" "gcr.io/distroless/cc-debian11" "${binpath}" # Need glibc image for system libraries.

  echo ""
  echo "Testing ${platform}: static linked user and system libraries"
  build_args+=(
    --features=fully_static_link
  )
  "${bazel}" --bazelrc=/dev/null build "${build_args[@]}" //:stdlib_test
  binpath="$(binpath_for "${build_args[@]}")"
  file "${binpath}" | tee /dev/stderr | grep -qE "${arch_regex}"
  check_with_image "${docker_platform}" "gcr.io/distroless/static-debian11" "${binpath}"
}

xcompile_test \
  "@toolchains_llvm//platforms:linux-x86_64" \
  "@llvm_toolchain_with_sysroot//:cc-toolchain-x86_64-linux" \
  "ELF.*x86-64" \
  "linux/amd64"

xcompile_test \
  "@toolchains_llvm//platforms:linux-aarch64" \
  "@llvm_toolchain_with_sysroot//:cc-toolchain-aarch64-linux" \
  "ELF.*(aarch64|ARM aarch64)" \
  "linux/arm64"
