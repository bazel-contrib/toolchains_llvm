#!/bin/bash
# Copyright 2026 The Bazel Authors.
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

fail() {
  echo >&2 "$@"
  exit 1
}

ld_lld_path=$1
stub_path=$2

[[ -e ${ld_lld_path} ]] || fail "bin/ld.lld not found at ${ld_lld_path}"
[[ -s ${stub_path} ]] || fail "stub lib/libxml2.so.2 not found at ${stub_path}"

# The stub must be a shared object (ELF magic, ET_DYN).
magic=$(head -c 4 "${stub_path}" | od -An -tx1 | tr -d ' \n')
[[ ${magic} == "7f454c46" ]] || fail "lib/libxml2.so.2 is not an ELF file: ${magic}"

# ld.lld must start and print its version without any libxml2 diagnostics.
# Without the stub this fails outright on hosts without a system
# libxml2.so.2, and prints "no version information available" on hosts
# with an unversioned compatibility symlink.
stderr=$("${ld_lld_path}" --version 2>&1 >/dev/null)
status=$?
[[ ${status} -eq 0 ]] || fail "ld.lld --version failed (${status}): ${stderr}"
if grep -q "libxml2" <<<"${stderr}"; then
  fail "ld.lld emitted libxml2 diagnostics: ${stderr}"
fi

echo "SUCCESS!"
