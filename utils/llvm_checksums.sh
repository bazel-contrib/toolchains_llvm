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
tmp_dir=
download=0

while getopts "t:v:ghDd" opt; do
  case "${opt}" in
  "d") download=1 ;;
  "D") download=0 ;;
  "g") use_github_host=1 ;;
  "h")
    echo "Usage:"
    echo "-t <tempdir> - Optional: Specify a temp directory to download distributions to."
    echo "-v <version> - Version of clang+llvm to use."
    echo "-g           - Use github to download releases."
    echo "-d           - Download the distribution tarballs."
    exit 2
    ;;
  "t") tmp_dir="${OPTARG}" ;;
  "v") llvm_version="${OPTARG}" ;;
  *)
    echo "invalid option: -${OPTARG}"
    exit 1
    ;;
  esac
done

if [[ -z ${llvm_version-} ]]; then
  echo "Usage: ${BASH_SOURCE[0]} [-t <tempdir>] [-g] [-d] -v <llvm_version>"
  exit 1
fi

cleanup() {
  rc=$?
  rm -rf "${tmp_dir}"
  exit "${rc}"
}

if [[ -z "${tmp_dir}" ]]; then
  tmp_dir="$(mktemp -d)"
  echo "Using temp dir: '${tmp_dir}'"
  trap 'cleanup' INT HUP QUIT TERM EXIT
else
  mkdir -p "${tmp_dir}"
fi

llvm_host() {
  local url_base="releases.llvm.org/${llvm_version}"
  output_dir="${tmp_dir}/${url_base}"
  wget --recursive --level 1 --directory-prefix="${tmp_dir}" \
    --accept-regex "(clang%2bllvm|LLVM)-.*tar.(xz|gz)$" "http://${url_base}/"
}

github_host() {
  output_dir="${tmp_dir}/${llvm_version}"
  mkdir -p "${output_dir}"

  # Fetch release JSON and extract asset info
  curl -s "https://api.github.com/repos/llvm/llvm-project/releases/tags/llvmorg-${llvm_version}" |
    tee "${output_dir}/releases.json" |
    jq -r '.assets[]|select(any(.name; test("^(clang[+]llvm|LLVM)-.*tar.(xz|gz)$")))|"    \""+(.browser_download_url|split("/")|.[-1]|sub("%2B";"+"))+"\": \""+.digest+"\","' \
      >"${output_dir}/checksums.txt"

  if ((download)); then
    # Download the actual tarballs using the already-fetched JSON
    jq -r '.assets[]|select(any(.name; test("^(clang[+]llvm|LLVM)-.*tar.(xz|gz)$")))|.browser_download_url' \
      "${output_dir}/releases.json" \
      >"${output_dir}/filtered_urls.txt"
    (
      cd "${output_dir}"
      xargs -n1 curl -L -O -C - <filtered_urls.txt
    )
  else
    echo "===="
    echo "Checksums for clang+llvm distributions are (${output_dir}):"
    echo "    # ${llvm_version}"
    cat "${output_dir}/checksums.txt"
    exit 0
  fi
}

if ((use_github_host)); then
  github_host
else
  llvm_host
fi

echo ""
echo "===="
echo "Checksums for clang+llvm distributions are (${output_dir}):"
echo "    # ${llvm_version}"
find "${output_dir}" -type f \( -name 'clang%2?llvm-*.tar.*' -o -name 'LLVM-*.tar.*' \) \( -name '*.gz' -o -name '*.xz' \) -exec shasum -a 256 {} \; |
  sed -e "s@${output_dir}/@@" |
  awk '{ printf "    \"%s\": \"%s\",\n", $2, $1 }' |
  sed -e 's/%2[Bb]/+/' |
  sort
