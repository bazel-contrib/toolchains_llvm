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

source "$(dirname "${BASH_SOURCE[0]}")/bazel.sh"
"${bazel}" version

# Generate some files needed for the tests.
"${bazel}" fetch @io_bazel_rules_go//tests/core/cgo:all
"$("${bazel}" info output_base)/external/io_bazel_rules_go/tests/core/cgo/generate_imported_dylib.sh"

test_args=(
  --incompatible_enable_cc_toolchain_resolution
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

# We exclude the following targets:
# - opts_test from rules_go because its include path assumes that the main repo is rules_go (see
#   https://github.com/bazelbuild/rules_go/issues/2955).
"${bazel}" --bazelrc=/dev/null test "${test_args[@]}" \
  //tests/foreign:pcre \
  @openssl//:libssl \
  $("${bazel}" query 'attr(timeout, short, tests(@com_google_absl//absl/...))') \
  $("${bazel}" query 'tests(@io_bazel_rules_go//tests/core/cgo:all) except set(@io_bazel_rules_go//tests/core/cgo:opts_test)')
