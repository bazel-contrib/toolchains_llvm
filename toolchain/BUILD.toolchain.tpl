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

package(default_visibility = ["//visibility:public"])

load("@rules_cc//cc:defs.bzl", "cc_toolchain", "cc_toolchain_suite")
load("%{cc_toolchain_config_bzl}", "cc_toolchain_config")

# Following filegroup targets are used when not using absolute paths and shared
# between different toolchains.

filegroup(
    name = "empty",
    srcs = [],
)

# Tools symlinked through this repo. This target is for internal use in the toolchain only.
filegroup(
    name = "internal-use-symlinked-tools",
    srcs = [
%{symlinked_tools}
    ],
)

# Tools wrapped through this repo. This target is for internal use in the toolchain only.
filegroup(
    name = "internal-use-wrapped-tools",
    srcs = [
        "bin/cc_wrapper.sh",
        "bin/host_libtool_wrapper.sh",
    ],
)

cc_import(
    name = "omp",
    shared_library = "%{llvm_repo_package}:lib/libomp.%{host_dl_ext}",
)

alias(
    name = "clang-format",
    actual = "%{llvm_repo_package}:bin/clang-format",
)

alias(
    name = "llvm-cov",
    actual = "%{llvm_repo_package}:bin/llvm-cov",
)

%{cc_toolchains}
