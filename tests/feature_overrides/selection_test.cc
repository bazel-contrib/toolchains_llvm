// Copyright 2026 The Bazel Authors.
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

#ifndef EXPECT_VARIANT
#error "The test runner must specify the expected toolchain variant"
#endif

#if EXPECT_VARIANT == 1
#ifndef FEATURE_TOOLCHAIN
#error "The conditional toolchain was not selected"
#endif
#ifndef OVERRIDE_SANDBOX_INPUT
#error "The overridden compiler input is missing"
#endif
static_assert(__cplusplus >= 202002L, "override must change the language standard");
#ifdef BASE_TOOLCHAIN
#error "override flags must replace inherited flags"
#endif
#elif EXPECT_VARIANT == 2
static_assert(__clang_major__ == 22, "override must change the LLVM distribution");
#if defined(BASE_TOOLCHAIN) || defined(FEATURE_TOOLCHAIN)
#error "reset must clear inherited compile flags"
#endif
#else
#ifndef BASE_TOOLCHAIN
#error "base flags are missing"
#endif
static_assert(__cplusplus == 201703L, "default must retain C++17");
#endif

// Exercise the selected distribution's C++ headers and runtime as well.
#include <string>

int main() { return std::string("toolchain").size() == 9 ? 0 : 1; }
