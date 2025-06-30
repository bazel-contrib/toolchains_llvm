#!/bin/bash
#
# Copyright 2021 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# shellcheck disable=SC1083

set -euo pipefail

CLEANUP_FILES=()

function cleanup() {
  if [[ ${#CLEANUP_FILES[@]} -gt 0 ]]; then
    rm -f "${CLEANUP_FILES[@]}"
  fi
}

trap cleanup EXIT

# See note in toolchain/internal/configure.bzl where we define
# `wrapper_bin_prefix` for why this wrapper is needed.

# this script is located at either
# - <execroot>/external/<repo_name>/bin/cc_wrapper.sh
# - <runfiles>/<repo_name>/bin/cc_wrapper.sh
# The clang is located at
# - <execroot>/external/<repo_name2>/bin/clang
# - <runfiles>/<repo_name2>/bin/clang
#
# In both cases, getting to clang can be done via
# Finding the current dir of this script,
# - <execroot>/external/<repo_name>/bin/
# - <runfiles>/<repo_name>/bin/
# going back 2 directories
# - <execroot>/external
# - <runfiles>
#
# Going into %{toolchain_path_prefix} without the `external/` prefix + `bin/clang`
#

dirname_shim() {
  local path="$1"

  # Remove trailing slashes
  path="${path%/}"

  # If there's no slash, return "."
  if [[ "${path}" != */* ]]; then
    echo "."
    return
  fi

  # Remove the last component after the final slash
  path="${path%/*}"

  # If it becomes empty, it means root "/"
  echo "${path:-/}"
}

script_dir=$(dirname_shim "${BASH_SOURCE[0]}")
toolchain_path_prefix="%{toolchain_path_prefix}"

# Sometimes this path may be an absolute path in which case we dont do anything because
# This is using the host toolchain to build.
if [[ ${toolchain_path_prefix} != /* ]]; then
  toolchain_path_prefix="${script_dir}/../../${toolchain_path_prefix#external/}"
fi

if [[ ! -f ${toolchain_path_prefix}bin/clang ]]; then
  echo >&2 "ERROR: could not find clang; PWD=\"${PWD}\"; PATH=\"${PATH}\"; toolchain_path_prefix=${toolchain_path_prefix}."
  exit 5
fi

function sanitize_option() {
  local -r opt=$1
  if [[ ${opt} == */cc_wrapper.sh ]]; then
    printf "%s" "${toolchain_path_prefix}bin/clang"
  elif [[ ${opt} =~ ^-fsanitize-(ignore|black)list=[^/] ]] && [[ ${script_dir} == /* ]]; then
    # shellcheck disable=SC2206
    parts=(${opt/=/ }) # Split flag name and value into array.
    printf "%s" "${parts[0]}=${script_dir}/../../../${parts[1]}"
  else
    printf "%s" "${opt}"
  fi
}

cmd=()
for ((i = 0; i <= $#; i++)); do
  if [[ ${!i} == @* && -r "${i:1}" ]]; then
    # Create a new, sanitized file.
    tmpfile=$(mktemp)
    CLEANUP_FILES+=("${tmpfile}")
    while IFS= read -r opt; do
      opt="$(
        set -e
        sanitize_option "${opt}"
      )"
      echo "${opt}" >>"${tmpfile}"
    done <"${!i:1}"
    cmd+=("@${tmpfile}")
  else
    opt="$(
      set -e
      sanitize_option "${!i}"
    )"
    cmd+=("${opt}")
  fi
done

# Call the C++ compiler.
"${cmd[@]}"
