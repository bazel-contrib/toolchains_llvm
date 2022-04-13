#!/bin/bash

fail() {
  >&2 echo "$@"
  exit 1
}

[[ -a "external/llvm_toolchain_llvm/bin/clang-format" ]] || fail "bin/clang-format not found"

[[ -a "external/llvm_toolchain_llvm/lib/libc++.a" ]] \
  || compgen -G 'external/llvm_toolchain_llvm/lib/*/libc++.a' >/dev/null \
  || fail "libc++.a not found"

echo "SUCCESS!"
