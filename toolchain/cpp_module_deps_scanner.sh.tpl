#!/bin/bash
#
# Copyright 2026 The Bazel Authors. All rights reserved.
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

set -euo pipefail

dirname_shim() {
  local path="$1"
  path="${path%/}"
  if [[ "${path}" != */* ]]; then
    echo "."
    return
  fi
  path="${path%/*}"
  echo "${path:-/}"
}

if [[ "${BASH_SOURCE[0]}" == /* ]]; then
  bash_source_abs="$(realpath "${BASH_SOURCE[0]}")"
  pwd_abs="$(realpath .)"
  bash_source_rel="${bash_source_abs#"${pwd_abs}/"}"
else
  bash_source_rel="${BASH_SOURCE[0]}"
fi
script_dir="$(dirname_shim "${bash_source_rel}")"
toolchain_path_prefix="%{toolchain_path_prefix}"

if [[ ${toolchain_path_prefix} != /* ]]; then
  toolchain_path_prefix="$(dirname_shim "$(dirname_shim "${script_dir}")")/${toolchain_path_prefix#external/}"
fi

exec "${toolchain_path_prefix}bin/clang-scan-deps" \
  -format=p1689 -- "${script_dir}/cc_wrapper.sh" "$@" >"${DEPS_SCANNER_OUTPUT_FILE}"
