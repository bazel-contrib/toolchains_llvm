#!/bin/bash

fail() {
  >&2 echo "$@"
  exit 1
}

[[ -a "external/llvm_toolchain/bin/clang-format" ]] || fail "bin/clang-format not found"

[[ -a "external/llvm_toolchain/lib/libc++.a" ]] || fail "lib/libc++.a not found"

echo "SUCCESS!"
