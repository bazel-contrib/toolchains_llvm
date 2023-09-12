#!/bin/bash
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

fail() {
  echo >&2 "$@"
  exit 1
}

clang_format_path=$1
libcpp_path=$2

[[ -e ${clang_format_path} ]] || fail "bin/clang-format not found"

[[ -e ${libcpp_path} ]] ||
  compgen -G "${libcpp_path}" >/dev/null ||
  fail "libc++.a not found"

echo "SUCCESS!"
