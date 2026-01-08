# Copyright 2021 The Bazel Authors.
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

# Some targets may need to directly depend on these files.
exports_files(glob(
    [
        "bin/*",
        "lib/**",
        "include/**",
        "share/clang/*",
    ],
    allow_empty = True,
))

## LLVM toolchain files

ALL_DLLS = glob(["bin/*.dll"], allow_empty=True)

filegroup(
    name = "clang",
    srcs = [
        "bin/clang.exe",
        "bin/clang++.exe",
        "bin/clang-cpp.exe",
        "bin/clang-cl.exe",
        "bin/lld-link.exe",
    ] + ALL_DLLS,
)

filegroup(
    name = "ld",
    # Not all distributions contain wasm-ld.
    srcs = [
        "bin/ld.lld.exe",
        "bin/ld64.lld.exe",
    ] + ALL_DLLS,
)

filegroup(
    name = "include",
    srcs = glob(
        [
            "include/**/c++/**",
            "lib/clang/*/include/**",
        ],
    ),
)

filegroup(
    name = "all_includes",
    srcs = glob(
        ["include/**"],
        allow_empty = True,
    ),
)

# This filegroup should only have source directories, not individual files.
# We rely on this assumption in system_module_map.bzl.
filegroup(
    name = "cxx_builtin_include",
    srcs = [
        "include/c++",
        "lib/clang/{LLVM_VERSION}/include",
    ],
)

filegroup(
    name = "extra_config_site",
    srcs = glob(["include/*/c++/v1/__config_site"], allow_empty = True)
)

filegroup(
    name = "bin",
    srcs = glob(["bin/**"]),
)

filegroup(
    name = "lib",
    srcs = [],
)

filegroup(
    name = "lib_legacy",
    srcs = [], # no reported Windows exec usage on older version of Bazel
)

filegroup(
    name = "ar",
    srcs = [
        "bin/llvm-ar.exe",
    ] + ALL_DLLS,
)

filegroup(
    name = "as",
    srcs = [
        "bin/clang.exe",
        "bin/llvm-as.exe",
    ] + ALL_DLLS,
)

filegroup(
    name = "nm",
    srcs = [
        "bin/llvm-nm.exe",
    ] + ALL_DLLS,
)

filegroup(
    name = "llvm-lib",
    srcs = [
        "bin/llvm-lib.exe",
    ] + ALL_DLLS,
)

filegroup(
    name = "objcopy",
    srcs = [
        "bin/llvm-objcopy.exe",
    ] + ALL_DLLS,
)

filegroup(
    name = "objdump",
    srcs = [
        "bin/llvm-objdump.exe",
    ] + ALL_DLLS,
)

filegroup(
    name = "profdata",
    srcs = [
        "bin/llvm-profdata.exe",
    ] + ALL_DLLS,
)

filegroup(
    name = "dwp",
    srcs = [
        "bin/llvm-dwp.exe",
    ] + ALL_DLLS,
)

filegroup(
    name = "ranlib",
    srcs = [
        "bin/llvm-ranlib.exe",
    ] + ALL_DLLS,
)

filegroup(
    name = "readelf",
    srcs = [
        "bin/llvm-readelf.exe",
    ] + ALL_DLLS,
)

filegroup(
    name = "strip",
    srcs = [
        "bin/llvm-strip.exe",
    ] + ALL_DLLS,
)

filegroup(
    name = "symbolizer",
    srcs = [
        "bin/llvm-symbolizer.exe",
    ] + ALL_DLLS,
)

filegroup(
    name = "clang-tidy",
    srcs = [
        "bin/clang-tidy.exe",
    ] + ALL_DLLS,
)

filegroup(
    name = "clang-format",
    srcs = [
        "bin/clang-format.exe",
    ] + ALL_DLLS,
)

filegroup(
    name = "git-clang-format",
    srcs = [
        "bin/git-clang-format.exe",
    ] + ALL_DLLS,
)

filegroup(
    name = "libclang",
    srcs = ["lib/libclang.lib"],
)
