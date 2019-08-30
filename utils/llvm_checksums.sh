#!/bin/bash

set -euo pipefail

while getopts "v:h" opt; do
  case "$opt" in
    "v") llvm_version="$OPTARG";;
    "h") echo "Usage:"
       echo "-v - Version of clang+llvm to use"
       exit 2
       ;;
    "?") echo "invalid option: -$OPTARG"; exit 1;;
  esac
done

if ! [[ "${llvm_version:-}" ]]; then
  echo "Usage: ${BASH_SOURCE[0]} -v llvm_version"
  exit 1
fi

tmp_dir="$(mktemp -d)"

cleanup() {
  rc=$?
  rm -rf "${tmp_dir}"
  exit $rc
}
trap 'cleanup' INT HUP QUIT TERM EXIT

(
cd "${tmp_dir}"
curl -s "https://api.github.com/repos/llvm/llvm-project/releases/tags/llvmorg-${llvm_version}" | \
  jq .assets[].browser_download_url | \
  tee /Users/sbagaria/Downloads/urls.txt | \
  grep 'clang%2Bllvm.*tar.xz"$' | \
  tee /Users/sbagaria/Downloads/filtered_urls.txt | \
  xargs -n1 curl -L -O
)

echo ""
echo "===="
echo "Checksums for clang+llvm distributions are:"
find "${tmp_dir}" -type f -name '*.xz' -exec shasum -a 256 {} \; | \
  sed -e "s@${tmp_dir}/@@" | \
  awk '{ printf "\"%s\": \"%s\",\n", $2, $1 }'
