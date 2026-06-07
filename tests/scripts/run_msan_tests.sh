#!/bin/bash
# Copyright 2024 The Bazel Authors.
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

# End-to-end MemorySanitizer test. Builds and runs //:msan_libcxx_test with the
# instrumented-libc++ toolchain (@llvm_toolchain_msan, configured via the
# `libcxx_url` attribute in tests/MODULE.bazel) and `--features=msan`. This
# links and runs an instrumented libc++, so it catches an uninstrumented libc++
# being linked under msan -- something the analysis-only msan_flags_test cannot.
#
# msan is Linux/x86_64 only and the toolchain is defined via bzlmod, so this is
# only run with USE_BZLMOD=true.

set -euo pipefail

while getopts "h" opt; do
  case "${opt}" in
  "h")
    echo "Usage: No options"
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
"${bazel}" ${TEST_MIGRATION:+"--strict"} test \
  "${common_test_args[@]}" \
  --extra_toolchains=@llvm_toolchain_msan//:all \
  --features=msan \
  -- //:msan_libcxx_test
