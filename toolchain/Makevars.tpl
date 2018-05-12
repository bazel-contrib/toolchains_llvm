# Copyright 2018 The Bazel Authors.
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

# Make variables if needed by build systems other than bazel, like R.

CC = %{toolchain_path_prefix}/bin/clang -std=c11
# Force compile packages with C++11 if they don't explicitly ask; this gives long vector support in Rcpp, etc.
CXX = %{toolchain_path_prefix}/bin/clang++ -std=c++11
CXX11 = %{toolchain_path_prefix}bin/clang++
CXX14 = %{toolchain_path_prefix}bin/clang++
CXX17 = %{toolchain_path_prefix}bin/clang++

CXX11STD = -std=c++11
CXX14STD = -std=c++14
CXX17STD = -std=c++1z

LDFLAGS += -fuse-ld=lld %{toolchain_path_prefix}/lib/libc++.a %{toolchain_path_prefix}/lib/libc++abi.a %{toolchain_path_prefix}/lib/libunwind.a -rtlib=compiler-rt -lpthread -ldl
CPPFLAGS += -B%{toolchain_path_prefix}bin -isystem %{toolchain_path_prefix}include/c++/v1 -isystem %{toolchain_path_prefix}lib/clang/%{llvm_version}/include -DLIBCXX_USE_COMPILER_RT=YES 
