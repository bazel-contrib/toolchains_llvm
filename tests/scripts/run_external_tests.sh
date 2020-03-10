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

os="$(uname -s | tr "[:upper:]" "[:lower:]")"
readonly os

# Use bazelisk for latest bazel version.
# Value of BAZELISK_GITHUB_TOKEN is set as a secret on Travis.
readonly url="https://github.com/bazelbuild/bazelisk/releases/download/v1.0/bazelisk-${os}-amd64"
bazel="${TMPDIR:-/tmp}/bazelisk"
readonly bazel

curl -L -sSf -o "${bazel}" "${url}"
chmod a+x "${bazel}"

"${bazel}" version

# We exclude cc_libs_test from rules_go because it assumes that stdlibc++ has
# been dynamically linked, but we link it statically on linux.
"${bazel}" --bazelrc=/dev/null test \
  --incompatible_enable_cc_toolchain_resolution \
  --symlink_prefix=/ \
  --color=yes \
  --show_progress_rate_limit=30 \
  --keep_going \
  --test_output=errors \
  @openssl//:libssl \
  $("${bazel}" query 'attr(timeout, short, tests(@com_google_absl//absl/...))') \
  $("${bazel}" query 'tests(@io_bazel_rules_go//tests/core/cgo:all) except @io_bazel_rules_go//tests/core/cgo:cc_libs_test')
