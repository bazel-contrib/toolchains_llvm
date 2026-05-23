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
# Refreshes toolchain/distributions/github.bzl with every
# llvm/llvm-project GitHub release at or above the configured minimum major
# version. Hand-maintained data for older releases lives in
# `toolchain/distributions/{pre_github,github_legacy}.bzl` and is not touched.
#
# Usage: utils/update_distributions.sh [-h]
#
# The script reads checksums from the GitHub release asset `.digest` field
# (no tarballs are downloaded). GitHub only began populating `.digest` in
# 2024, so for older assets the script preserves the checksum already
# present in `github.bzl`. To avoid the 60/hour unauthenticated API rate
# limit, the script uses (in order): the `GITHUB_TOKEN` env var, or the
# token from the `gh` CLI if it is installed and authenticated.
#
# For one-off lookups of a single version's checksums (e.g. to paste into
# `extra_llvm_distributions`), use `utils/extra_distributions.sh` instead.
#
# Requires: bash, curl, jq, and awk. Runs in Git Bash / MSYS2 / WSL on
# Windows; native cmd/PowerShell is not supported.
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

while getopts "h" opt; do
  case "${opt}" in
  "h") usage 0 ;;
  *) usage ;;
  esac
done

missing=()
for cmd in curl jq awk; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    missing+=("${cmd}")
  fi
done
if ((${#missing[@]} > 0)); then
  echo "ERROR: required commands not found in PATH: ${missing[*]}" >&2
  exit 1
fi

# Versions below this major use the pre-19.x irregular naming scheme and
# remain in `github_legacy.bzl` / `pre_github.bzl`. Keep in sync with the
# docstring in `toolchain/distributions/github.bzl`.
MIN_MAJOR=19

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="${repo_root}/toolchain/distributions/github.jsonc"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT INT HUP QUIT TERM

# Pick up a GitHub token: explicit env var wins; otherwise fall back to the
# `gh` CLI if it's installed and authenticated. Unauthenticated requests are
# capped at 60/hour, which is not enough to finish a full release scan.
token="${GITHUB_TOKEN-}"
if [[ -z "${token}" ]] && command -v gh >/dev/null 2>&1; then
  token="$(gh auth token 2>/dev/null || true)"
  if [[ -n "${token}" ]]; then
    echo "Using GitHub token from gh CLI." >&2
  fi
fi

curl_args=(--fail --silent --show-error)
if [[ -n "${token}" ]]; then
  curl_args+=(-H "Authorization: Bearer ${token}")
else
  echo "WARNING: no GITHUB_TOKEN set and no authenticated gh CLI found." >&2
  echo "         Unauthenticated GitHub API is capped at 60 requests/hour." >&2
  echo "         Set GITHUB_TOKEN or run 'gh auth login' to authenticate." >&2
fi

echo "Fetching llvm-project releases from GitHub..." >&2
all="${tmp_dir}/releases.jsonl"
: >"${all}"
page=1
while :; do
  body="${tmp_dir}/page-${page}.json"
  if ! curl "${curl_args[@]}" \
    "https://api.github.com/repos/llvm/llvm-project/releases?per_page=100&page=${page}" \
    >"${body}" 2>"${tmp_dir}/curl.err"; then
    cat "${tmp_dir}/curl.err" >&2
    echo "Hint: if this is a 403, the token is missing/expired or you hit the" >&2
    echo "      GitHub API rate limit. Set GITHUB_TOKEN or run 'gh auth login'." >&2
    exit 1
  fi
  count="$(jq 'length' "${body}")"
  if [[ "${count}" -eq 0 ]]; then
    break
  fi
  jq -c '.[]' "${body}" >>"${all}"
  if [[ "${count}" -lt 100 ]]; then
    break
  fi
  page=$((page + 1))
done

# Extract existing entries from github.jsonc so we can preserve checksums for
# assets whose `.digest` field is missing on GitHub, and preserve any
# maintainer-set `_meta.base_url` overrides verbatim. We parse via jq after
# stripping JSONC `//` comments -- much sturdier than line-pattern matching.
existing="${tmp_dir}/existing.tsv"
existing_base_url="${tmp_dir}/existing_base_url.tsv"
if [[ -f "${output}" ]]; then
  # Convert JSONC to strict JSON for jq. We must (a) drop full-line `//`
  # comments and (b) strip trailing commas before `}`/`]`. The runtime JSONC
  # parser tolerates trailing commas, but jq does not. We deliberately do not
  # strip mid-line `//` -- that would corrupt string values like
  # `"http://..."` or `(the "License");`.
  stripped="${tmp_dir}/stripped.json"
  awk '
    /^[[:space:]]*\/\// { next }
    { lines[++n] = $0 }
    END {
      for (i = 1; i <= n; i++) {
        line = lines[i]
        j = i + 1
        while (j <= n && lines[j] ~ /^[[:space:]]*$/) j++
        if (j <= n && lines[j] ~ /^[[:space:]]*[}\]]/) {
          sub(/,[[:space:]]*$/, "", line)
        }
        print line
      }
    }
  ' "${output}" >"${stripped}"
  jq -r 'to_entries[] | select(.key != "_meta") | "\(.key)\t\(.value)"' \
    "${stripped}" >"${existing}"
  jq -r '._meta.base_url // {} | to_entries[] | "\(.key)\t\(.value)"' \
    "${stripped}" >"${existing_base_url}"
else
  : >"${existing}"
  : >"${existing_base_url}"
fi

echo "Extracting matching assets..." >&2
jq -r '
  select(.prerelease | not)
  | select(.tag_name | test("^llvmorg-[0-9]+\\.[0-9]+\\.[0-9]+$"))
  | (.tag_name | ltrimstr("llvmorg-")) as $version
  | .assets[]
  | select(.name | test("^(clang[+]llvm|LLVM)-.*tar.(xz|gz)$"))
  | [$version, .name, ((.digest // "") | sub("^sha256:"; ""))] | @tsv
' "${all}" >"${tmp_dir}/entries.raw.tsv"

# Merge in existing checksums for entries whose .digest is missing, drop
# entries below MIN_MAJOR, then sort by (version, name).
awk -F'\t' -v min="${MIN_MAJOR}" -v existing="${existing}" '
  BEGIN {
    while ((getline line < existing) > 0) {
      n = index(line, "\t")
      if (n == 0) continue
      prev[substr(line, 1, n - 1)] = substr(line, n + 1)
    }
    close(existing)
  }
  {
    version = $1; name = $2; digest = $3
    split(version, v, ".")
    if (v[1]+0 < min) next
    if (digest == "") {
      if (name in prev) digest = prev[name]
      else missing[name] = 1
    }
    key = sprintf("%05d.%05d.%05d", v[1]+0, v[2]+0, v[3]+0)
    print key "\t" version "\t" name "\t" digest
  }
  END {
    for (n in missing) print "MISSING\t" n > "/dev/stderr"
  }
' "${tmp_dir}/entries.raw.tsv" 2>"${tmp_dir}/missing.txt" |
  sort -t $'\t' -k1,1r -k3,3 |
  cut -f2- >"${tmp_dir}/entries.tsv"

if [[ -s "${tmp_dir}/missing.txt" ]]; then
  echo "ERROR: new GitHub release assets are missing a .digest field and have no" >&2
  echo "       existing entry to preserve. Add them to github.jsonc by hand, then" >&2
  echo "       rerun this script:" >&2
  cut -f2 "${tmp_dir}/missing.txt" | sed 's/^/  /' >&2
  exit 1
fi

entries_total="$(wc -l <"${tmp_dir}/entries.tsv" | tr -d ' ')"
versions_total="$(cut -f1 "${tmp_dir}/entries.tsv" | sort -u | wc -l | tr -d ' ')"
echo "Writing ${entries_total} entries across ${versions_total} versions to ${output}..." >&2

# The GitHub release URL template used as the per-file default. The runtime
# substitutes `{version}` at materialization time and appends the basename.
GITHUB_URL_TEMPLATE='https://github.com/llvm/llvm-project/releases/download/llvmorg-{version}/'

# Filter preserved per-version overrides to versions still present in the new
# entries, sorted newest-first to match the data section. The `""` default key
# is emitted unconditionally below, so it's stripped here.
cut -f1 "${tmp_dir}/entries.tsv" | sort -u >"${tmp_dir}/versions_kept.txt"
awk -F'\t' -v versions_file="${tmp_dir}/versions_kept.txt" '
  BEGIN {
    while ((getline v < versions_file) > 0) kept[v] = 1
    close(versions_file)
  }
  $1 != "" && ($1 in kept)
' "${existing_base_url}" | sort -t $'\t' -k1,1Vr >"${tmp_dir}/base_url_kept.tsv"

{
  cat <<'HEAD'
// Copyright 2018 The Bazel Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// This file is generated end-to-end by `utils/update_distributions.sh`.
// Do not edit by hand. To add a new release, run the script with no
// arguments to fetch all known GitHub releases and rewrite this file.

{
  "_meta": {
    "description": "GitHub-hosted LLVM distributions (version 19.x and newer). Regenerated by utils/update_distributions.sh.",
    "base_url": {
HEAD
  # Default `""` template applies to every entry whose version lacks an
  # explicit per-version override below.
  if [[ -s "${tmp_dir}/base_url_kept.tsv" ]]; then
    printf '      "": "%s",\n' "${GITHUB_URL_TEMPLATE}"
    awk -F'\t' '
      { entries[NR] = $0 }
      END {
        for (i = 1; i <= NR; i++) {
          split(entries[i], f, "\t")
          comma = (i < NR) ? "," : ""
          printf("      \"%s\": \"%s\"%s\n", f[1], f[2], comma)
        }
      }
    ' "${tmp_dir}/base_url_kept.tsv"
  else
    printf '      "": "%s"\n' "${GITHUB_URL_TEMPLATE}"
  fi
  cat <<'MID'
    }
  },

MID
  awk -F'\t' '
    { entries[NR] = $0 }
    END {
      n = NR
      for (i = 1; i <= n; i++) {
        split(entries[i], f, "\t")
        version = f[1]
        name    = f[2]
        digest  = f[3]
        if (version != prev) {
          if (prev != "") print ""
          printf("  // %s\n", version)
          prev = version
        }
        comma = (i < n) ? "," : ""
        printf("  \"%s\": \"%s\"%s\n", name, digest, comma)
      }
    }
  ' "${tmp_dir}/entries.tsv"
  echo "}"
} >"${output}"

# Regenerate the golden file consumed by `llvm_distributions_output_test`. The
# golden enumerates every known distribution (so adding entries to github.bzl
# invariably changes it). We invoke the `distributions_test_writer` rule
# directly and copy its output -- running `bazel test` would just fail with a
# diff, which is exactly what we are fixing.
golden="${repo_root}/toolchain/internal/llvm_distributions.golden.out.txt"
echo "Updating ${golden}..." >&2
if ! command -v bazel >/dev/null 2>&1; then
  echo "ERROR: bazel not on PATH; cannot regenerate the golden file." >&2
  echo "       github.bzl has been written; rerun under bazel to refresh" >&2
  echo "       the golden." >&2
  exit 1
fi
(
  cd "${repo_root}"
  bazel build //toolchain/internal:llvm_distributions >&2
  bazel_bin="$(bazel info bazel-bin)"
  cp -f "${bazel_bin}/toolchain/internal/llvm_distributions.out.txt" "${golden}"
)

echo "Done." >&2
