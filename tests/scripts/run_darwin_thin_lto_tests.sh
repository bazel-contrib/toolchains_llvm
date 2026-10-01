#!/bin/bash
# Copyright 2026 The Bazel Authors.
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

# The test cannot link unless ThinLTO eliminates an unresolved call through
# both C and C++ libraries. No explicit -flto flags are supplied by this script.
set -euo pipefail

scripts_dir="${BASH_SOURCE[0]%/*}"
source "${scripts_dir}/bazel.sh"
cd "${scripts_dir}/.."

case "$(uname -m)" in
arm64) toolchain="@llvm_toolchain_local_linker//:cc-toolchain-aarch64-darwin" ;;
x86_64) toolchain="@llvm_toolchain_local_linker//:cc-toolchain-x86_64-darwin" ;;
*)
  echo "Unsupported macOS architecture" >&2
  exit 1
  ;;
esac

common_test_args+=(
  "--repo_env=LLVM_VERSION=23.1.2"
  "--extra_toolchains=${toolchain}"
  "--repositories_without_autoloads=cc_compatibility_proxy"
  "--compilation_mode=opt"
)

"${bazel}" --bazelrc=/dev/null test "${common_test_args[@]}" \
  --features=thin_lto //thin_lto:flags_tests //thin_lto:thin_lto_test

# Disabling ThinLTO must fail for the intended reason, not a download or SDK
# error. This also proves the positive test is not merely an ordinary build.
expect_unoptimized_failure() {
  local output
  if output="$("${bazel}" --bazelrc=/dev/null build "${common_test_args[@]}" "$@" 2>&1)"; then
    echo "ERROR: UNOPTIMIZED THINLTO PROBE UNEXPECTEDLY LINKED" >&2
    return 1
  fi
  if [[ ${output} != *'Undefined symbols'* || ${output} != *'thin_lto_missing_optimization'* ]]; then
    printf '%s\n' "${output}" >&2
    echo "ERROR: EXPECTED THE THINLTO PROBE'S UNRESOLVED SYMBOL" >&2
    return 1
  fi
  echo "Verified expected link failure without ThinLTO: $*"
}

expect_unoptimized_failure --features=thin_lto --features=-thin_lto //thin_lto:thin_lto_test

# Target features must not leak into the exec configuration; --host_features
# enables ThinLTO explicitly for build tools instead.
expect_unoptimized_failure --features=thin_lto //thin_lto:thin_lto_tool
"${bazel}" --bazelrc=/dev/null build "${common_test_args[@]}" \
  --features=-thin_lto --host_features=thin_lto //thin_lto:thin_lto_tool
