#!/bin/bash
set -euo pipefail

scripts_dir="${BASH_SOURCE[0]%/*}"
# shellcheck source=tests/scripts/bazel.sh
source "${scripts_dir}/bazel.sh"
cd "${scripts_dir}/../msan_catalogue"
common_test_args+=("--repositories_without_autoloads=cc_compatibility_proxy" "--lockfile_mode=off")

if [[ ${short_uname} == Linux ]]; then
  "${bazel}" --bazelrc=/dev/null test "${common_test_args[@]}" \
    --features=msan --spawn_strategy=sandboxed //:all
fi

# Linux CI cross-compiles x86_64 -> ARM64; macOS CI also crosses OS boundaries.
# Compile/link with the target compiler-rt, instrumented libc++ and sysroot.
"${bazel}" --bazelrc=/dev/null build "${common_test_args[@]}" \
  --features=msan --spawn_strategy=sandboxed --platforms=//:linux_arm64 \
  //:stdlib_test //:c_instrumentation_test
arm_binary="$("${bazel}" --bazelrc=/dev/null cquery "${common_args[@]}" \
  --repositories_without_autoloads=cc_compatibility_proxy --lockfile_mode=off \
  --symlink_prefix=/ --features=msan --platforms=//:linux_arm64 \
  --output=files //:stdlib_test)"
execution_root="$("${bazel}" --bazelrc=/dev/null info "${common_args[@]}" execution_root)"
file "${execution_root}/${arm_binary}" | tee /dev/stderr | grep -F 'ARM aarch64'

log="$(mktemp)"
trap 'rm -f "${log}"' EXIT
if [[ ${short_uname} == Linux ]]; then
  for disabled in none explicit; do
    # The ordinary compiler must be restored when MSan is absent/disabled. The
    # source refuses to compile without instrumentation; never run it silently.
    flags=()
    if [[ ${disabled} == explicit ]]; then
      flags+=(--features=msan --features=-msan)
    fi
    if "${bazel}" --bazelrc=/dev/null build "${common_test_args[@]}" \
      "${flags[@]}" //:stdlib_test >"${log}" 2>&1; then
      echo "ERROR: MSAN TEST COMPILED WITHOUT MEMORYSANITIZER INSTRUMENTATION" >&2
      exit 1
    fi
    cat "${log}"
    grep -F "THIS TEST REQUIRES MEMORYSANITIZER INSTRUMENTATION" "${log}"
  done
fi
