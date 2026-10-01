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

# A crash or an ordinary nonzero exit is not proof of MSan instrumentation.
set -euo pipefail

output_file="$(mktemp)"
trap 'rm -f "${output_file}"' EXIT
status=0
MSAN_OPTIONS=halt_on_error=1:exitcode=86 "$1" >"${output_file}" 2>&1 || status=$?
cat "${output_file}"
if [[ ${status} -ne 86 ]] || ! grep -q 'MemorySanitizer: use-of-uninitialized-value' "${output_file}"; then
  echo "ERROR: EXPECTED AN MSAN UNINITIALIZED-VALUE DIAGNOSTIC AND EXIT CODE 86" >&2
  exit 1
fi
