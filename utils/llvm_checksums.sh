#!/bin/bash
# Copyright 2022 The Bazel Authors.
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

use_github_host=0

while getopts "v:gh" opt; do
  case "${opt}" in
  "v") llvm_version="${OPTARG}" ;;
  "g") use_github_host=1 ;;
  "h")
    echo "Usage:"
    echo "-v - Version of clang+llvm to use"
    echo "-g - Use github to download releases"
    exit 2
    ;;
  *)
    echo "invalid option: -${OPTARG}"
    exit 1
    ;;
  esac
done

if [[ -z ${llvm_version-} ]]; then
  echo "Usage: ${BASH_SOURCE[0]} [-g] -v llvm_version"
  exit 1
fi

tmp_dir="$(mktemp -d)"

cleanup() {
  rc=$?
  rm -rf "${tmp_dir}"
  exit "${rc}"
}
trap 'cleanup' INT HUP QUIT TERM EXIT

llvm_host() {
  local url_base="releases.llvm.org/${llvm_version}"
  output_dir="${tmp_dir}/${url_base}"
  wget --recursive --level 1 --directory-prefix="${tmp_dir}" \
    --accept-regex "clang%2bllvm.*tar.xz$" "http://${url_base}/"
}

github_host() {
  output_dir="${tmp_dir}"
  (
    cd "${output_dir}"
    curl -s "https://api.github.com/repos/llvm/llvm-project/releases/tags/llvmorg-${llvm_version}" |
      jq .assets[].browser_download_url |
      tee ./urls.txt |
      grep 'clang%2Bllvm.*tar.xz"$' |
      tee ./filtered_urls.txt |
      xargs -n1 curl -L -O
  )
}

if ((use_github_host)); then
  github_host
else
  llvm_host
fi

echo ""
echo "===="
echo "Checksums for clang+llvm distributions are:"
find "${output_dir}" -type f -name '*.xz' -exec shasum -a 256 {} \; |
  sed -e "s@${output_dir}/@@" |
  awk '{ printf "\"%s\": \"%s\",\n", $2, $1 }' |
  sed -e 's/%2[Bb]/+/' |
  sort
