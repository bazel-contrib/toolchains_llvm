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

# Proves that requesting MSan on macOS fails conspicuously instead of silently
# running an uninstrumented build. CI runs this with Bazel 9 and LLVM 23.

set -euo pipefail

readonly llvm_version="23.1.2"
scripts_dir="${BASH_SOURCE[0]%/*}"
source "${scripts_dir}/bazel.sh"
"${bazel}" version

machine="$(uname -m)"
case "${machine}" in
arm64) toolchain="@llvm_toolchain_local_linker//:cc-toolchain-aarch64-darwin" ;;
x86_64) toolchain="@llvm_toolchain_local_linker//:cc-toolchain-x86_64-darwin" ;;
*)
  echo "Unsupported macOS architecture: ${machine}" >&2
  exit 1
  ;;
esac

cd "${scripts_dir}/.."
set +e
output="$("${bazel}" --bazelrc=/dev/null build \
  "${common_test_args[@]}" \
  --extra_toolchains="${toolchain}" \
  --features=msan \
  --repo_env="LLVM_VERSION=${llvm_version}" \
  //:stdlib_bin 2>&1)"
status=$?
set -e

printf '%s\n' "${output}"
if [[ ${status} -eq 0 ]]; then
  echo "ERROR: unsupported macOS MSan build unexpectedly succeeded" >&2
  exit 1
fi

readonly expected="FATAL ERROR: MEMORYSANITIZER (MSAN) IS NOT SUPPORTED FOR DARWIN TARGETS"
if [[ ${output} != *"${expected}"* ]]; then
  echo "ERROR: unsupported macOS MSan build did not emit the required fatal error" >&2
  exit 1
fi
