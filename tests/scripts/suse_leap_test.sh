#!/bin/bash
# Copyright 2021 The Bazel Authors.
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

set -euox pipefail

images=(
  "opensuse/leap:latest"
)

# See note next to the definition of this toolchain in the WORKSPACE file.
toolchain="@llvm_toolchain_13_0_0//:cc-toolchain-x86_64-linux"

git_root=$(git rev-parse --show-toplevel)
readonly git_root

echo "git root: ${git_root}"

for image in "${images[@]}"; do
  docker pull "${image}"
  docker run --rm --entrypoint=/bin/bash --env USE_BZLMOD --volume="${git_root}:/src" "${image}" -c """
set -exuo pipefail

# Common setup
zypper -n update
zypper -n install curl gcc libc++1

# Run tests
cd /src
tests/scripts/run_tests.sh -t ${toolchain}
"""
done
