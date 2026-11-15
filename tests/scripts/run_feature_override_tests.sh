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

# Check the declared compiler, header and static runtime action inputs, not only
# the compiler's version macros. Linux uses the distribution's libc++; macOS
# keeps its SDK libc++ policy, but must still declare the correct LLVM inputs.
check_distribution_roots() {
  local expected_root="$1"
  local forbidden_root="$2"
  shift 2
  local actions
  actions="$("${bazel}" --bazelrc=/dev/null aquery "${common_test_args[@]}" \
    --output=text "$@" 'mnemonic("Cpp(Compile|Link)", //:selection_test)')"
  local suffix
  for suffix in '/bin/clang' '/include/c++'; do
    if ! grep -Fq "${expected_root}${suffix}" <<<"${actions}"; then
      echo >&2 "Missing compiler/header input ${expected_root}${suffix}"
      return 1
    fi
  done
  if ! grep -Eq "${expected_root}/lib/[^ ,]*libc[+][+][.]a" <<<"${actions}"; then
    echo >&2 "Missing libc++ runtime input from ${expected_root}"
    return 1
  fi
  if grep -Fq "${forbidden_root}/" <<<"${actions}"; then
    echo >&2 "Unexpected inherited compiler/header/runtime input from ${forbidden_root}"
    return 1
  fi
}

# Existing behavior: a download-only fallback can select another LLVM version,
# as MBO/XFF do for MSan. No caller-provided roots are needed for that feature.
run_test 0 --extra_toolchains=@llvm_download_toolchain//:all
run_test 2 --extra_toolchains=@llvm_download_toolchain//:all --features=test_distribution
check_distribution_roots llvm_download_toolchain_feature_0_llvm llvm_download_toolchain_llvm \
  --extra_toolchains=@llvm_download_toolchain//:all --features=test_distribution

# Matching is exact on the mentioned features; unrelated features are ignored.
run_test 0
check_distribution_roots llvm_download_toolchain_llvm llvm_toolchain_feature_1_llvm
run_test 0 --features=test_override
run_test 1 --features=test_override --features=test_second --features=unrelated
check_distribution_roots llvm_download_toolchain_llvm llvm_toolchain_feature_1_llvm \
  --features=test_override --features=test_second
run_test 0 --features=test_override --features=test_second --features=test_disable
run_test 1 --features=test_override --features=test_second --features=test_disable --features=-test_disable
run_test 0 --features=test_override --features=test_second --features=-test_second

"${bazel}" --bazelrc=/dev/null test "${common_test_args[@]}" \
  --copt=-DEXPECT_VARIANT=0 //:per_rule_features_test

# Regression: with external fallback roots, select LLVM 22's compiler, headers
# AND runtime, without resetting either root. Only compile flags are reset.
run_test 2 --features=test_distribution
check_distribution_roots llvm_toolchain_feature_1_llvm llvm_download_toolchain_llvm \
  --features=test_distribution

# On Linux the default is downloaded mold. LTO must select bundled LLD,
# including Bazel's ThinLTO indexing actions, with no LLVMgold.so dependency.
run_test 0 --features=thin_lto
check_distribution_roots llvm_download_toolchain_llvm llvm_toolchain_feature_1_llvm --features=thin_lto

# Build tools use the exec configuration, independently of target --features.
"${bazel}" --bazelrc=/dev/null build "${common_test_args[@]}" \
  --features=test_override --features=test_second \
  --host_copt=-DEXPECT_VARIANT=0 //:exec_selection
"${bazel}" --bazelrc=/dev/null build "${common_test_args[@]}" \
  --host_features=test_override --host_features=test_second \
  --host_copt=-DEXPECT_VARIANT=1 //:exec_selection
