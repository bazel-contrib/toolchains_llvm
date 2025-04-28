#!/usr/bin/env bash

set -euo pipefail

grep -v "ERROR:" \
  "${TEST_SRCDIR}/_main/toolchain/internal/llvm_distributions.golden.sel.txt" \
  >"${TEST_TMPDIR}/llvm_distributions.golden.sel.no_error.txt"
grep -v "ERROR:" \
  "${TEST_SRCDIR}/_main/toolchain/internal/llvm_distributions.sel.txt" \
  >"${TEST_TMPDIR}/llvm_distributions.sel.no_error.txt"

diff -U0 \
  "${TEST_TMPDIR}/llvm_distributions.golden.sel.no_error.txt" \
  "${TEST_TMPDIR}/llvm_distributions.sel.no_error.txt"
