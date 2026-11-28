#!/bin/bash
set -euo pipefail

scripts_dir="${BASH_SOURCE[0]%/*}"
# shellcheck source=tests/scripts/bazel.sh
source "${scripts_dir}/bazel.sh"
cd "${scripts_dir}/../hermetic_llvm"

# Match the WORKSPACE compatibility proxy used by the other focused suites.
common_test_args+=("--repositories_without_autoloads=cc_compatibility_proxy" "--lockfile_mode=off")
# Exercise both release-specific URL templates and automatic upgrades. Checking
# Clang's patch version in the source prevents a silent fallback to an older
# archive (or a compiler outside this catalogue) from passing.
for selection in "23.1.2" "23.1.6" "latest:major==23"; do
  patchlevel=6
  if [[ ${selection} == "23.1.2" ]]; then
    patchlevel=2
  fi
  version_args=("--repo_env=LLVM_VERSION=${selection}" "--copt=-DEXPECTED_LLVM_PATCHLEVEL=${patchlevel}")
  echo "Testing hermetic-llvm ${selection} (expected Clang 23.1.${patchlevel})"
  "${bazel}" --bazelrc=/dev/null test "${common_test_args[@]}" "${version_args[@]}" \
    --spawn_strategy=sandboxed //:stdlib_test
done

# No sanitizer runtimes are shipped with this compiler-only profile. Reject
# the request at analysis time, before an obscure missing-library link error.
log="$(mktemp)"
trap 'rm -f "${log}"' EXIT
if "${bazel}" --bazelrc=/dev/null test "${common_test_args[@]}" "${version_args[@]}" \
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
  if "${bazel}" --bazelrc=/dev/null test "${common_test_args[@]}" "${version_args[@]}" \
    --features=test_bad_stdlib //:stdlib_test >"${log}" 2>&1; then
    echo "ERROR: compiler-only catalogue unexpectedly accepted bundled libc++" >&2
    exit 1
  fi
  cat "${log}"
  grep -F "INCOMPATIBLE LLVM DISTRIBUTION" "${log}"
  grep -F "stdlib 'builtin-libc++' is not supported" "${log}"
fi
