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

# OS X relpath is not really working. This is a wrapper script around gcc
# to simulate relpath behavior.
#
# This wrapper uses install_name_tool to replace all paths in the binary
# (bazel-out/.../path/to/original/library.so) by the paths relative to
# the binary. It parses the command line to behave as rpath is supposed
# to work.
#
# See https://blogs.oracle.com/dipol/entry/dynamic_libraries_rpath_and_mac
# on how to set those paths for Mach-O binaries.

# shellcheck disable=SC1083

set -eu

# See note in toolchain/internal/configure.bzl where we define
# `wrapper_bin_prefix` for why this wrapper is needed.

# Call the C++ compiler.
if [[ -f %{toolchain_path_prefix}bin/clang ]]; then
  exec %{toolchain_path_prefix}bin/clang "$@"
elif [[ ${BASH_SOURCE[0]} == "/"* ]]; then
  # Some consumers of `CcToolchainConfigInfo` (e.g. `cmake` from rules_foreign_cc)
  # change CWD and call $CC (this script) with its absolute path.
  # the execroot (i.e. `cmake` from `rules_foreign_cc`) and call CC . For cases like this,
  # we'll try to find `clang` relative to this script.
  # This script is at _execroot_/external/_repo_name_/bin/clang_wrapper.sh
  execroot_path="${BASH_SOURCE[0]%/*/*/*/*}"
  clang="${execroot_path}/%{toolchain_path_prefix}bin/clang"
  exec "${clang}" "${@}"
else
  echo >&2 "ERROR: could not find clang; PWD=\"${PWD}\"; PATH=\"${PATH}\"."
  exit 5
fi
