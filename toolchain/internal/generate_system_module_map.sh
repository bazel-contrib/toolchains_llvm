#!/bin/sh
# Based on:
# https://github.com/bazelbuild/bazel/blob/44c5a1bbb26d3c61b37529b38406f1f5b0832baf/tools/cpp/generate_system_module_map.sh
#
# Copyright 2020 The Bazel Authors. All rights reserved.
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

set -eu

echo 'module "crosstool" [system] {'

for dir in "$@"; do
  find -L "${dir}" -type f 2>/dev/null | LANG=C sort | uniq | while read -r header; do
    case "${dir}" in
    /*) ;;
    *) header="${EXECROOT_PREFIX}${header}" ;;
    esac
    # The module map is expected to contain all possibly transitively included headers, including
    # those provided by the sysroot or the host machine.
    echo "  textual header \"${header}\""
  done
done

echo "}"
