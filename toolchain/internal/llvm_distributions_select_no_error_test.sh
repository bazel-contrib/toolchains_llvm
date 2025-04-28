#!/usr/bin/env bash

set -euxo pipefail

cat "${TEST_SRCDIR}/_main/toolchain/internal/llvm_distributions.golden.sel.txt" |\
    grep -v "ERROR:" > "${TEST_TMPDIR}/llvm_distributions.golden.sel.no_error.txt"
cat "${TEST_SRCDIR}/_main/toolchain/internal/llvm_distributions.sel.txt" |\
    grep -v "ERROR:" > "${TEST_TMPDIR}/llvm_distributions.sel.no_error.txt"

diff -U0 -I '.*ERROR:.*' \
    "${TEST_TMPDIR}/llvm_distributions.golden.sel.no_error.txt" \
    "${TEST_TMPDIR}/llvm_distributions.sel.no_error.txt"
