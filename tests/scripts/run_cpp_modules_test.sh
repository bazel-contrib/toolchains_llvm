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

set -euo pipefail

scripts_dir="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=tests/scripts/bazel.sh
source "${scripts_dir}/bazel.sh"
cd "${scripts_dir}/.."

"${bazel}" --bazelrc=/dev/null test \
  "${common_test_args[@]}" \
  --experimental_cpp_modules \
  --features=cpp_modules \
  --cxxopt=-std=c++23 \
  --repo_env=LLVM_VERSION=22.1.8 \
  //:cpp20_module_test
