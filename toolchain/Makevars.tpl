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

CC = clang -std=c11
# Force compile packages with C++11 if they don't explicitly ask; this gives long vector support in Rcpp, etc.
CXX = clang++ -std=c++11
CXX11 = clang++
CXX14 = clang++
CXX17 = clang++

CXX11STD = -std=c++11
CXX14STD = -std=c++14
CXX17STD = -std=c++1z

CPPFLAGS += -stdlib=libc++ -DLIBCXX_USE_COMPILER_RT=YES

LDFLAGS += %{makevars_ld_flags} -rtlib=compiler-rt -lpthread -ldl -nostdlib++
LDFLAGS += _EXEC_ROOT_/%{toolchain_path_prefix}lib/libc++.a
LDFLAGS += _EXEC_ROOT_/%{toolchain_path_prefix}lib/libc++abi.a
LDFLAGS += _EXEC_ROOT_/%{toolchain_path_prefix}lib/libunwind.a
