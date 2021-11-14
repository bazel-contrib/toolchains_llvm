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

images=(
"archlinux:base-devel"
)

git_root=$(git rev-parse --show-toplevel)
readonly git_root

for image in "${images[@]}"; do
  docker pull "${image}"
  docker run --rm --entrypoint=/bin/bash --volume="${git_root}:/src:ro" "${image}" -c """
set -exuo pipefail

# add archlinuxcn repo for ncurses5-compat-libs (can be installed from AUR, but this is easier & faster)
cat >> /etc/pacman.conf <<'EOF'
[archlinuxcn]
Server = https://repo.archlinuxcn.org/\$arch
EOF

# Install dependencies
pacman -Syu --noconfirm --quiet archlinuxcn-keyring python ncurses5-compat-libs

# Run tests
cd /src
tests/scripts/run_tests.sh
"""
done
