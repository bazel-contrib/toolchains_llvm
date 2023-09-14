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

scripts_dir="$(dirname "${BASH_SOURCE[0]}")"
source "${scripts_dir}/bazel.sh"
"${bazel}" version

cd "${scripts_dir}"

# Generate some files needed for the tests.
"${bazel}" query "${common_args[@]}" @io_bazel_rules_go//tests/core/cgo:dylib_test >/dev/null
if [[ ${USE_BZLMOD} == "true" ]]; then
  "$("${bazel}" info output_base)/external/rules_go~0.41.0/tests/core/cgo/generate_imported_dylib.sh"
else
  "$("${bazel}" info output_base)/external/io_bazel_rules_go/tests/core/cgo/generate_imported_dylib.sh"
fi

test_args=(
  "${common_test_args[@]}"
  "--copt=-Wno-deprecated-builtins" # https://github.com/abseil/abseil-cpp/issues/1201
)

# We exclude the following targets:
# - cc_libs_test from rules_go because it assumes that stdlibc++ has been dynamically linked, but we
#   link it statically on linux.
# - external_includes_test from rules_go because it is a nested bazel test and so takes a long time
#   to run, and it is not particularly useful to us.
# - time_zone_format_test from abseil-cpp because it assumes TZ is set to America/Los_Angeles, but
#   we run the tests in UTC.
#   The rules_rust tests should be:
# @rules_rust//test/unit/{native_deps,linkstamps,interleaved_cc_info}:all
#   but under bzlmod the linkstamp tests fail due to the fact we are currently
#   overriding rules_rust locally as its not yet released in the BCR
# shellcheck disable=SC2207
absl_targets=($("${bazel}" query "${common_args[@]}" 'attr(timeout, short, tests(@com_google_absl//absl/...))'))
"${bazel}" --bazelrc=/dev/null test "${test_args[@]}" -- \
  //foreign:pcre \
  @openssl//:libssl \
  @rules_rust//test/unit/interleaved_cc_info:all \
  @io_bazel_rules_go//tests/core/cgo:all \
  -@io_bazel_rules_go//tests/core/cgo:cc_libs_test \
  -@io_bazel_rules_go//tests/core/cgo:external_includes_test \
  "${absl_targets[@]}" \
  -@com_google_absl//absl/time/internal/cctz:time_zone_format_test
