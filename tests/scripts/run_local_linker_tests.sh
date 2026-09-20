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

system_name="$(uname -s)"
machine="$(uname -m)"
platform="${system_name}-${machine}"

case "${platform}" in
Darwin-arm64) toolchain="@llvm_toolchain_local_linker//:cc-toolchain-aarch64-darwin" ;;
Darwin-x86_64) toolchain="@llvm_toolchain_local_linker//:cc-toolchain-x86_64-darwin" ;;
Linux-aarch64) toolchain="@llvm_toolchain_local_linker//:cc-toolchain-aarch64-linux" ;;
Linux-x86_64) toolchain="@llvm_toolchain_local_linker//:cc-toolchain-x86_64-linux" ;;
*)
  echo "Unsupported execution platform: ${platform}" >&2
  exit 1
  ;;
esac

scripts_dir="${BASH_SOURCE[0]%/*}"
"${scripts_dir}/run_tests.sh" -O -W -t "${toolchain}"
