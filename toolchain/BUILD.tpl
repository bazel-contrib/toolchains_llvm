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

exports_files(["Makevars"])

filegroup(
    name = "empty",
    srcs = [],
)

filegroup(
    name = "cc_wrapper",
    srcs = ["cc_wrapper.sh"],
)

cc_toolchain_suite(
    name = "toolchain",
    toolchains = {
        "k8|clang": ":cc-clang-linux",
        "darwin|clang": ":cc-clang-darwin",
    },
)

load("@com_grail_bazel_toolchain//toolchain:configure.bzl", "conditional_cc_toolchain")

conditional_cc_toolchain("cc-clang-linux", "k8", False, %{absolute_paths})
conditional_cc_toolchain("cc-clang-darwin", "darwin", True, %{absolute_paths})

filegroup(
    name = "clang",
    srcs = [
        "bin/clang",
        "bin/clang++",
        "bin/clang-cpp",
    ],
)

filegroup(
    name = "ld",
    srcs = [
        "bin/ld.lld",
        "bin/ld64.lld"
    ],
)

filegroup(
    name = "include",
    srcs = glob([
        "include/c++/**",
        "lib/clang/*/include/**",
    ]),
)

filegroup(
    name = "lib",
    srcs = [
        "lib/libc++.a",
        "lib/libc++abi.a",
        "lib/libunwind.a",
    ],
)

filegroup(
    name = "compiler_components",
    srcs = [
        ":clang",
        ":include",
    ],
)

filegroup(
    name = "ar",
    srcs = ["bin/llvm-ar"],
)

filegroup(
    name = "as",
    srcs = ["bin/llvm-as"],
)

filegroup(
    name = "nm",
    srcs = ["bin/llvm-nm"],
)

filegroup(
    name = "objcopy",
    srcs = ["bin/llvm-objcopy"],
)

filegroup(
    name = "objdump",
    srcs = ["bin/llvm-objdump"],
)

filegroup(
    name = "profdata",
    srcs = ["bin/llvm-profdata"],
)

filegroup(
    name = "dwp",
    srcs = ["bin/llvm-dwp"],
)

filegroup(
    name = "ranlib",
    srcs = ["bin/llvm-ranlib"],
)

filegroup(
    name = "readelf",
    srcs = ["bin/llvm-readelf"],
)

filegroup(
    name = "binutils_components",
    srcs = [
        ":ar",
        ":as",
        ":dwp",
        ":ld",
        ":nm",
        ":objcopy",
        ":objdump",
        ":profdata",
        ":ranlib",
        ":readelf",
    ],
)

filegroup(
    name = "linker_components",
    srcs = [
        ":ar",
        ":clang",
        ":ld",
        ":lib",
    ],
)

filegroup(
    name = "all_components",
    srcs = [
        ":binutils_components",
        ":compiler_components",
        ":linker_components",
    ],
)
