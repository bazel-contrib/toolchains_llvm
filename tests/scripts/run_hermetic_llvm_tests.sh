#!/bin/bash
set -euo pipefail

scripts_dir="${BASH_SOURCE[0]%/*}"
# shellcheck source=tests/scripts/bazel.sh
source "${scripts_dir}/bazel.sh"
cd "${scripts_dir}/../hermetic_llvm"

# Match the WORKSPACE compatibility proxy used by the other focused suites.
common_test_args+=("--repositories_without_autoloads=cc_compatibility_proxy" "--lockfile_mode=off")
"${bazel}" --bazelrc=/dev/null test "${common_test_args[@]}" \
  --spawn_strategy=sandboxed //:stdlib_test

# No sanitizer runtimes are shipped with this compiler-only profile. Reject
# the request at analysis time, before an obscure missing-library link error.
log="$(mktemp)"
if "${bazel}" --bazelrc=/dev/null test "${common_test_args[@]}" \
  --features=asan //:stdlib_test >"${log}" 2>&1; then
  echo "ERROR: compiler-only catalogue unexpectedly accepted ASan" >&2
  exit 1
fi
cat "${log}"
grep -F "INCOMPATIBLE LLVM DISTRIBUTION" "${log}"
grep -F "feature 'asan' must be disabled" "${log}"

system_name="$(uname -s)"
if [[ ${system_name} == "Linux" ]]; then
  # The inactive override must not break the normal build above. When
  # selected, its inherited archive metadata must reject bundled libc++.
  if "${bazel}" --bazelrc=/dev/null test "${common_test_args[@]}" \
    --features=test_bad_stdlib //:stdlib_test >"${log}" 2>&1; then
    echo "ERROR: compiler-only catalogue unexpectedly accepted bundled libc++" >&2
    exit 1
  fi
  cat "${log}"
  grep -F "INCOMPATIBLE LLVM DISTRIBUTION" "${log}"
  grep -F "stdlib 'builtin-libc++' is not supported" "${log}"
fi
