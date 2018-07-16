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

url_base="releases.llvm.org/${llvm_version}"
tmp_dir="$(mktemp -d)"

cleanup() {
  rc=$?
  rm -rf "${tmp_dir}"
  exit $rc
}
trap 'cleanup' INT HUP QUIT TERM EXIT

wget --compression gzip --recursive --level 1 --directory-prefix="${tmp_dir}" \
  --accept-regex "clang%2bllvm.*tar.xz$" "http://${url_base}/"

echo ""
echo "===="
echo "Checksums for clang+llvm distributions are:"
output_dir="${tmp_dir}/${url_base}"
find "${output_dir}" -type f -name '*.xz' -exec shasum -a 256 {} \; | \
  sed -e "s@${output_dir}/@@" | \
  awk '{ printf "\"%s\": \"%s\",\n", $2, $1 }'
