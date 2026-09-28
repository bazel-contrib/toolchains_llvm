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

set -euo pipefail

readonly llvm_version="23.1.2"
system_name="$(uname -s)"
readonly system_name
machine="$(uname -m)"
readonly machine
scripts_dir="${BASH_SOURCE[0]%/*}"
source "${scripts_dir}/bazel.sh"
"${bazel}" version

cd "${scripts_dir}/.."
if [[ ${system_name} == "Darwin" ]]; then
  case "${machine}" in
  arm64) toolchain="@llvm_toolchain_local_linker//:cc-toolchain-aarch64-darwin" ;;
  x86_64) toolchain="@llvm_toolchain_local_linker//:cc-toolchain-x86_64-darwin" ;;
  *)
    echo "Unsupported macOS architecture: ${machine}" >&2
    exit 1
    ;;
  esac
else
  toolchain=""
fi

"${bazel}" --bazelrc=/dev/null test \
  "${common_test_args[@]}" \
  --extra_toolchains="${toolchain}" \
  --repo_env="LLVM_VERSION=${llvm_version}" \
  //:stdlib_test
