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

toolchain_name="llvm_toolchain"

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

os="$(uname -s | tr "[:upper:]" "[:lower:]")"
readonly os
# github API is rate limited, making use of bazelisk unpredictable because bazelisk uses the API to fetch bazel release information.
#readonly url="https://github.com/philwo/bazelisk/releases/download/v0.0.4/bazelisk-${os}-amd64"
readonly url="https://github.com/bazelbuild/bazel/releases/download/0.25.0/bazel-0.25.0-${os}-x86_64"

bazel="${TMPDIR:-/tmp}/bazel"
readonly bazel

curl -L -sSf -o "${bazel}" "${url}"
chmod a+x "${bazel}"

set -x
"${bazel}" version
"${bazel}" test \
  --crosstool_top="@${toolchain_name}//:toolchain" \
  --copt=-v \
  --linkopt=-Wl,-t \
  --symlink_prefix=/ \
  --color=yes \
  --show_progress_rate_limit=30 \
  --keep_going \
  --test_output=errors \
  //...
