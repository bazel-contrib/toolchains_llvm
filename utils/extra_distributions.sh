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
#
# --- BEGIN HELP ---
# Print SHA-256 checksums for one LLVM release, formatted for direct pasting
# into the `extra_llvm_distributions` argument of llvm.toolchain(...) in your
# MODULE.bazel. Use this only when the version you want is not yet present in
# the bundled `//toolchain/distributions:github.jsonc` -- otherwise just bump
# `llvm_version` and let the toolchain pick the existing entries up.
#
# Usage: utils/extra_distributions.sh [-d] [-t <tempdir>] -v <version>
#   -v <version>  LLVM release version (e.g. 19.1.0).
#   -d            Force download tarballs and recompute SHA-256s locally
#                 even when GitHub provides a .digest field.
#   -t <tempdir>  Reuse a specific temp directory (kept after exit).
#                 Default: a fresh mktemp dir, removed on exit.
#   -h            Show this help.
#
# By default the script uses GitHub's `.digest` field where available (no
# downloads). For older assets where `.digest` is absent, it falls back to
# downloading the tarball and computing the SHA-256 with `shasum -a 256`.
# Set GITHUB_TOKEN to avoid the unauthenticated API rate limit.
#
# To refresh the entire bundled list of GitHub-hosted releases (the data
# behind the toolchain's built-in version table), use
# `utils/update_distributions.sh` instead.
#
# Requires: bash, curl, jq, awk, and either `sha256sum` (Linux, Git Bash) or
# `shasum` (macOS). Runs in Git Bash / MSYS2 / WSL on Windows; native
# cmd/PowerShell is not supported.
# --- END HELP ---

set -euo pipefail

# Extract the help block (lines between the BEGIN/END HELP markers above),
# strip the leading "# " from each line, and emit to stderr.
usage() {
  awk '
    /^# --- BEGIN HELP ---/ { flag = 1; next }
    /^# --- END HELP ---/   { flag = 0; next }
    flag                    { sub(/^# ?/, ""); print }
  ' "${BASH_SOURCE[0]}" >&2
  exit "${1:-2}"
}

llvm_version=
tmp_dir=
force_download=0

while getopts "dht:v:" opt; do
  case "${opt}" in
  "d") force_download=1 ;;
  "h") usage 0 ;;
  "t") tmp_dir="${OPTARG}" ;;
  "v") llvm_version="${OPTARG}" ;;
  *) usage ;;
  esac
done

if [[ -z "${llvm_version}" ]]; then
  usage
fi

if [[ -z "${tmp_dir}" ]]; then
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' EXIT INT HUP QUIT TERM
else
  mkdir -p "${tmp_dir}"
fi

curl_args=(--fail --silent --show-error -L)
if [[ -n "${GITHUB_TOKEN-}" ]]; then
  curl_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

release_json="${tmp_dir}/release.json"
echo "Fetching llvmorg-${llvm_version} release metadata..." >&2
curl "${curl_args[@]}" \
  "https://api.github.com/repos/llvm/llvm-project/releases/tags/llvmorg-${llvm_version}" \
  >"${release_json}"

# Asset table: name <TAB> digest (may be empty) <TAB> download URL.
assets_tsv="${tmp_dir}/assets.tsv"
jq -r '
  .assets[]
  | select(.name | test("^(clang[+]llvm|LLVM)-.*tar.(xz|gz)$"))
  | [.name, ((.digest // "") | sub("^sha256:"; "")), .browser_download_url] | @tsv
' "${release_json}" >"${assets_tsv}"

if [[ ! -s "${assets_tsv}" ]]; then
  echo "ERROR: no matching tarball assets found for llvmorg-${llvm_version}." >&2
  exit 1
fi

# Portable SHA-256: prefer `sha256sum` (Linux, Git Bash, MSYS2), fall back to
# `shasum -a 256` (stock macOS). Both emit `<hex>  <path>` on the first line.
if command -v sha256sum >/dev/null 2>&1; then
  sha256_cmd=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  sha256_cmd=(shasum -a 256)
else
  echo "ERROR: need either sha256sum or shasum on PATH." >&2
  exit 1
fi

sums_tsv="${tmp_dir}/sums.tsv"
: >"${sums_tsv}"
while IFS=$'\t' read -r name digest url; do
  sha="${digest}"
  if [[ -z "${sha}" || ${force_download} -eq 1 ]]; then
    echo "Downloading ${name}..." >&2
    file="${tmp_dir}/${name}"
    curl "${curl_args[@]}" -C - -o "${file}" "${url}"
    sha="$("${sha256_cmd[@]}" "${file}" | awk '{print $1}')"
  fi
  printf '%s\t%s\n' "${name}" "${sha}" >>"${sums_tsv}"
done <"${assets_tsv}"

echo "" >&2
echo "    # ${llvm_version}"
sort "${sums_tsv}" | awk -F'\t' '{ printf("    \"%s\": \"%s\",\n", $1, $2) }'
