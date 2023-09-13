#!/bin/bash
# Copyright 2018 The Bazel Authors.
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

toolchain_name=""

while getopts "t:h" opt; do
  case "${opt}" in
  "t") toolchain_name="${OPTARG}" ;;
  "h")
    echo "Usage:"
    echo "-t - Toolchain name to use for testing; default is llvm_toolchain"
    exit 2
    ;;
  *)
    echo "invalid option: -${OPTARG}"
    exit 1
    ;;
  esac
done

scripts_dir="$(dirname "${BASH_SOURCE[0]}")"
source "${scripts_dir}/bazel.sh"
"${bazel}" version

cd "${scripts_dir}"

set -x
test_args=(
  "--extra_toolchains=${toolchain_name}"
  "--copt=-v"
  "--linkopt=-Wl,-t"
)

"${bazel}" ${TEST_MIGRATION:+"--strict"} --bazelrc=/dev/null test \
  "${common_test_args[@]}" "${test_args[@]}" //:all

# Note that the following flags are currently known to cause issues in migration tests:
# --incompatible_disallow_struct_provider_syntax # https://github.com/bazelbuild/bazel/issues/7347
# --incompatible_no_rule_outputs_param # from rules_rust
