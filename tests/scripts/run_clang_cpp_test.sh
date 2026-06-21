#!/bin/bash
# Copyright 2024 The Bazel Authors.
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

# Builds and runs //:clang_cpp_test, exercising the
# `@llvm_toolchain_llvm//:clang_cpp` target by compiling against the Clang/LLVM
# development headers and linking libclang-cpp.
#
# Built in `-c opt`: clang_cpp is expected to be consumed only in opt (or
# host-opt) configuration, so the test mirrors that.
#
# C++ standard library: the upstream LLVM *Linux* release is built against
# libstdc++ (its libclang-cpp.so exports e.g. the cxx11-ABI-tagged
# `getClangFullVersion[abi:cxx11]`), so a consumer built with libc++ -- the
# toolchains_llvm default -- fails to link with `undefined symbol`. We therefore
# build the test against libstdc++ on Linux via the dynamic-stdc++ toolchain
# (libclang-cpp.so itself pulls libstdc++.so.6, so a shared libstdc++ matches).
# macOS ships a libc++-built libclang-cpp.dylib, so the default toolchain works.
#
# The target is tagged `manual` (libclang-cpp is not shipped by every LLVM
# distribution), so it is run explicitly here rather than via `//:all`. Only run
# on Ubuntu and macOS with the latest Bazel; older toolchains/distributions are
# not guaranteed to ship libclang-cpp.

set -euo pipefail

while getopts "h" opt; do
  case "${opt}" in
  "h")
    echo "Usage: No options"
    exit 2
    ;;
  *)
    echo "invalid option: -${OPTARG}"
    exit 1
    ;;
  esac
done

# On Linux, match the libstdc++ ABI of the prebuilt libclang-cpp by selecting
# the dynamic-stdc++ toolchain. On macOS the default (libc++) toolchain matches.
toolchain_name=""
host_os="$(uname -s | tr '[:upper:]' '[:lower:]')"
if [[ "${host_os}" != "darwin" ]]; then
  host_arch="$(uname -m)"
  if [[ "${host_arch}" == "aarch64" ]] || [[ "${host_arch}" == "arm64" ]]; then
    host_arch="aarch64"
  fi
  toolchain_name="@llvm_toolchain_dynamic_stdcpp//:cc-toolchain-${host_arch}-linux"
fi

scripts_dir="$(dirname "${BASH_SOURCE[0]}")"
source "${scripts_dir}/bazel.sh"
"${bazel}" version

if [[ -n "${toolchain_name}" ]]; then
  common_test_args+=("--extra_toolchains=${toolchain_name}")
fi

cd "${scripts_dir}"

set -x
"${bazel}" ${TEST_MIGRATION:+"--strict"} test \
  "${common_test_args[@]}" \
  --compilation_mode=opt \
  --verbose_failures \
  -- //:clang_cpp_test
