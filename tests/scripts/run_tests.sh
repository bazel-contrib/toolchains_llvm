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
  case "$opt" in
    "t") toolchain_name="$OPTARG";;
    "h") echo "Usage:"
       echo "-t - Toolchain name to use for testing; default is llvm_toolchain"
       exit 2
       ;;
    "?") echo "invalid option: -$OPTARG"; exit 1;;
  esac
done

source "$(dirname "${BASH_SOURCE[0]}")/bazel.sh"
"${bazel}" version

set -x
test_args=(
  --extra_toolchains="${toolchain_name}"
  --incompatible_enable_cc_toolchain_resolution
  --copt=-v
  --linkopt=-Wl,-t
  --symlink_prefix=/
  --color=yes
  --show_progress_rate_limit=30
  --keep_going
  --test_output=errors
)
if [[ "${TEST_MIGRATION:-}" ]]; then
  # We can not use bazelisk to test migration because bazelisk does not allow
  # us to selectively ignore a migration flag.
  test_args+=("--all_incompatible_changes")
  # This flag is not quite ready -- https://github.com/bazelbuild/bazel/issues/7347
  test_args+=("--incompatible_disallow_struct_provider_syntax=false")
fi
"${bazel}"  --bazelrc=/dev/null test "${test_args[@]}" //tests:all
