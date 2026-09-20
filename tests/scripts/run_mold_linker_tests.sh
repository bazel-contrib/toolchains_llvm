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

system_name="$(uname -s)"
machine="$(uname -m)"
if [[ ${system_name}-${machine} != "Linux-x86_64" ]]; then
  echo "The mold integration fixture requires Linux-x86_64" >&2
  exit 1
fi

scripts_dir="${BASH_SOURCE[0]%/*}"
"${scripts_dir}/run_tests.sh" -O -T -W -t "@llvm_toolchain_mold//:cc-toolchain-x86_64-linux"
