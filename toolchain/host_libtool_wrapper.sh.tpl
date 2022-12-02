#!/usr/bin/env bash
# Copyright 2022 The Bazel Authors.
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

# Some older `libtool` versions (~macOS 10.12) don't support arg files.
#
# This script flattens arg files into regular command line arguments.

args=()
for a in "${@}"; do
  if [[ ${a} =~ @.* ]]; then
    IFS=$'\n' read -d '' -r -a args_in_file < "${a:1}"
    for arg in "${args_in_file[@]}"; do
        args+=("${arg}")
    done
  else
    args+=("${a}")
  fi
done

exec "%{libtool_path}" "${args[@]}"
