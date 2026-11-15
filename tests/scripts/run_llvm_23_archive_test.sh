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

test_log="$(mktemp "${TMPDIR:-/tmp}/llvm-23-archive-test.XXXXXX")"
readonly test_log
trap 'rm -f "${test_log}"' EXIT

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
  --repo_env="LLVM_VERSION=first:==${llvm_version}" \
  //:stdlib_test 2>&1 | tee "${test_log}"

if [[ -n ${EXPECTED_LLVM_ARCHIVE_SUFFIX:-} ]]; then
  # A selector constrained to one release logs the selected archive. Verify
  # that CI exercised the expected compression, not merely a successful build.
  resolved_archives="$(grep -F ": LLVM-${llvm_version}-" "${test_log}" || true)"
  if [[ -z ${resolved_archives} ]]; then
    # A repeated local run may reuse repositories without resolving or
    # extracting an archive. CI starts with fresh repositories.
    echo "Reused cached LLVM repositories; no new archive extraction to check."
  elif ! grep -F "${EXPECTED_LLVM_ARCHIVE_SUFFIX}" <<<"${resolved_archives}"; then
    echo "ERROR: Expected LLVM ${llvm_version} to select ${EXPECTED_LLVM_ARCHIVE_SUFFIX}" >&2
    exit 1
  fi
fi
