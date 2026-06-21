// Copyright 2024 The Bazel Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Exercises the `@llvm_toolchain_llvm//:clang_cpp` target: it must be possible
// to include the Clang/LLVM development headers and link against libclang-cpp
// (which statically embeds LLVM). We pull in a symbol that is defined inside
// libclang-cpp -- `clang::getClangFullVersion()` -- so the test fails to link
// if the shared library is missing from the target, and fails to compile if the
// headers are not exposed.

#include <cstdio>
#include <string>

#include "clang/Basic/Version.h"

int main() {
  const std::string version = clang::getClangFullVersion();
  std::printf("clang version: %s\n", version.c_str());
  // The version string embeds the LLVM release, so it is never empty when the
  // symbol resolved against the real libclang-cpp.
  return version.empty() ? 1 : 0;
}
