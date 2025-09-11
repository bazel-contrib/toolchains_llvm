#!/bin/sh
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

set -euo

cleanup() {
  while read -r f; do
    rm -f "${f}"
  done <"${CLEANUP_FILES}"
}

CLEANUP_FILES=""

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
  path="$1"

  # Remove trailing slashes
  path="${path%/}"

  # If there's no slash, return "."
  if [ "${path}" != "*/*" ]; then
    echo "."
    return
  fi

  # Remove the last component after the final slash
  path="${path%/*}"

  # If it becomes empty, it means root "/"
  echo "${path:-/}"
}

script_dir=$(dirname_shim "$0")
toolchain_path_prefix="%{toolchain_path_prefix}"

# Sometimes this path may be an absolute path in which case we dont do anything because
# This is using the host toolchain to build.
case "${toolchain_path_prefix}" in
/*) ;;
*) toolchain_path_prefix="${script_dir}/../../${toolchain_path_prefix#external/}" ;;
esac

if [ ! -f "${toolchain_path_prefix}bin/clang" ]; then
  echo >&2 "ERROR: could not find clang; PWD=\"${PWD}\"; PATH=\"${PATH}\"; toolchain_path_prefix=${toolchain_path_prefix}."
  exit 5
fi

OUTPUT=

parse_option() {
  po_opt="$1"
  if [ "${OUTPUT}" = "1" ]; then
    OUTPUT=${po_opt}
  elif [ "${po_opt}" = "-o" ]; then
    # output is coming
    OUTPUT=1
  fi
}

sanitize_option() {
  so_opt="$1"
  case ${so_opt} in
  */cc_wrapper.sh) printf "%s" "${toolchain_path_prefix}bin/clang" ;;
  *)
    if eval "case ${so_opt} in -fsanitize-ignorelist=*|-fsanitize-blacklist=*) [ ${script_dir} == /* ] ;; esac"; then
      # Split flag name and value.
      #
      # shellcheck disable=SC2206
      part0=$(echo "${so_opt}" | cut -d '=' -f 1)
      part1=$(echo "${so_opt}" | cut -d '=' -f 2)
      printf "%s" "${part0}=${script_dir}/../../../${part1}"
    else
      printf "%s" "${so_opt}"
    fi
    ;;
  esac
}

COUNT=$#
i=0
while [ "${i}" -le "${COUNT}" ]; do
  temp=""
  eval "temp=\${${i}}"
  substr="${temp#?}"
  if eval "case ${temp} in @*) [ -r \"{substr}\" ] ;; esac"; then
    # Create a new, sanitized file.
    tmpfile=$(mktemp)
    # POSIX shell does not support arrays, so we write the cleanup files as an
    # array-separated list. We do not need to worry about spaces in filenames,
    # because `mktemp` cannot use them when using the default template.
    CLEANUP_FILES="${CLEANUP_FILES} ${tmpfile}"
    while IFS= read -r opt; do
      opt="$(
        set -e
        sanitize_option "${opt}"
      )"
      parse_option "${opt}"
      echo "${opt}" >>"${tmpfile}"
    done <"${substr}"
    cmd="${cmd} ${tmpfile}"
  else
    opt="$(
      set -e
      sanitize_option "${temp}"
    )"
    parse_option "${opt}"
    # The items within $cmd also cannot contain spaces, because of how
    # `sanitize_option` behaves.
    cmd="${cmd} ${opt}"
  fi
  i=$((i + 1))
done

# Call the C++ compiler.
eval \""${cmd}"\"

# Generate an empty file if header processing succeeded.
if [ "${OUTPUT}" = "*.h.processed" ]; then
  true >"${OUTPUT}"
fi
