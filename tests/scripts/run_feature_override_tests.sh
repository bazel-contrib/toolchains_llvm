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

scripts_dir="${BASH_SOURCE[0]%/*}"
source "${scripts_dir}/bazel.sh"
cd "${scripts_dir}/../feature_overrides"

# rules_cc's compatibility proxy must load Bazel's native symbols on Bazel 8.
common_test_args+=("--repositories_without_autoloads=cc_compatibility_proxy")

run_test() {
  local expected="$1"
  shift
  "${bazel}" --bazelrc=/dev/null test "${common_test_args[@]}" \
    "--copt=-DEXPECT_VARIANT=${expected}" "$@" //:selection_test
}

# Matching is exact on the mentioned features; unrelated features are ignored.
run_test 0
run_test 0 --features=test_override
run_test 1 --features=test_override --features=test_second --features=unrelated
run_test 0 --features=test_override --features=test_second --features=test_disable
run_test 0 --features=test_override --features=test_second --features=-test_second

"${bazel}" --bazelrc=/dev/null test "${common_test_args[@]}" \
  --copt=-DEXPECT_VARIANT=0 //:per_rule_features_test

# Distribution attributes and explicit resets are not restricted to flags.
run_test 2 --features=test_distribution

# On Linux the default is downloaded mold. LTO must select bundled LLD,
# including Bazel's ThinLTO indexing actions, with no LLVMgold.so dependency.
run_test 0 --features=thin_lto

# Build tools use the exec configuration, independently of target --features.
"${bazel}" --bazelrc=/dev/null build "${common_test_args[@]}" \
  --features=test_override --features=test_second \
  --host_copt=-DEXPECT_VARIANT=0 //:exec_selection
"${bazel}" --bazelrc=/dev/null build "${common_test_args[@]}" \
  --host_features=test_override --host_features=test_second \
  --host_copt=-DEXPECT_VARIANT=1 //:exec_selection
