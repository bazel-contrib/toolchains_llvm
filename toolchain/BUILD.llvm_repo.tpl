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
    # Not all distributions contain wasm-ld.
    srcs = [
        "bin/ld.lld",
        "bin/ld64.lld",
    ] + glob(
        ["bin/wasm-ld"],
        allow_empty = True,
    ),
)

filegroup(
    name = "include",
    srcs = glob([
        "include/**",
        "lib/clang/*/include/**",
    ]) + glob(
        [
            # Sanitizer ignorelists (e.g. msan_ignorelist.txt) that Clang
            # auto-loads from the resource directory when a sanitizer is
            # enabled; they must be available as compiler inputs.
            "lib/clang/*/share/**",
            # msan-instrumented libc++ headers, present only when the
            # distribution was configured with the `libcxx_url` attribute.
            "libcxx-msan/include/**",
        ],
        allow_empty = True,
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
    ] + glob(
        # Sanitizer ignorelists (e.g. msan_ignorelist.txt) auto-loaded by Clang
        # from the resource directory when a sanitizer is enabled.
        ["lib/clang/{LLVM_VERSION}/share"],
        allow_empty = True,
    ) + glob(
        # msan-instrumented libc++ headers, present only when the distribution
        # was configured with the `libcxx_url` attribute. Matched as source
        # directories (exclude_directories = 0) so they are emitted as umbrella
        # submodules in the system module map and are available as compiler
        # inputs, matching the `include/c++` entry above.
        [
            "libcxx-msan/include/c++",
            "libcxx-msan/include/*/c++",
        ],
        exclude_directories = 0,
        allow_empty = True,
    ),
)

filegroup(
    name = "extra_config_site",
    srcs = glob(
        ["include/*/c++/v1/__config_site"],
        allow_empty = True,
    ),
)

filegroup(
    name = "bin",
    srcs = glob(["bin/**"]),
)

filegroup(
    name = "lib",
    srcs = [
        # Include the .dylib files in the linker sandbox even though they will
        # not be available at runtime to allow sanitizers to work locally.
        # Any library linked from the toolchain to be released should be linked statically.
        "lib/clang/{LLVM_VERSION}/lib",
    ] + glob(
        [
            "lib/**/libc++*.a",
            "lib/**/libunwind.a",
            # msan-instrumented libc++ libraries, present only when the
            # distribution was configured with the `libcxx_url` attribute.
            "libcxx-msan/lib/**/lib*.a",
        ],
        allow_empty = True,
    ),
)

filegroup(
    name = "lib_legacy",
    srcs = glob(
        [
            # Include the .dylib files in the linker sandbox even though they will
            # not be available at runtime to allow sanitizers to work locally.
            # Any library linked from the toolchain to be released should be linked statically.
            "lib/clang/{LLVM_VERSION}/lib/**",
            "lib/**/libc++*.a",
            "lib/**/libunwind.a",
            # msan-instrumented libc++ libraries, present only when the
            # distribution was configured with the `libcxx_url` attribute.
            # These must be linker-sandbox inputs; otherwise `-l:libc++.a`
            # silently falls back to the uninstrumented base libc++.a and
            # produces MSan false positives.
            "libcxx-msan/lib/**/lib*.a",
        ],
        allow_empty = True,
    ),
)

# Sanitizer runtime dylibs on macOS. Unlike Linux (where the runtimes are
# static archives linked into the binary), Clang on macOS links sanitized
# binaries against `@rpath/libclang_rt.<san>_osx_dynamic.dylib`, so the dylib
# must be locatable at runtime. These filegroups let the darwin cc_toolchain
# expose the matching runtime as `dynamic_runtime_lib`, which Bazel links via
# the solib directory and ships in the binary's runfiles. Empty on non-darwin
# distributions.
filegroup(
    name = "libclang_rt-asan-darwin",
    srcs = glob(
        ["lib/clang/{LLVM_VERSION}/lib/darwin/libclang_rt.asan_osx_dynamic.dylib"],
        allow_empty = True,
    ),
)

filegroup(
    name = "libclang_rt-tsan-darwin",
    srcs = glob(
        ["lib/clang/{LLVM_VERSION}/lib/darwin/libclang_rt.tsan_osx_dynamic.dylib"],
        allow_empty = True,
    ),
)

filegroup(
    name = "libclang_rt-ubsan-darwin",
    srcs = glob(
        ["lib/clang/{LLVM_VERSION}/lib/darwin/libclang_rt.ubsan_osx_dynamic.dylib"],
        allow_empty = True,
    ),
)

filegroup(
    name = "ar",
    srcs = ["bin/llvm-ar"],
)

filegroup(
    name = "as",
    srcs = [
        "bin/clang",
        "bin/llvm-as",
    ],
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
    name = "strip",
    srcs = ["bin/llvm-strip"],
)

filegroup(
    name = "symbolizer",
    srcs = ["bin/llvm-symbolizer"],
)

filegroup(
    name = "clang-tidy",
    srcs = ["bin/clang-tidy"],
)

filegroup(
    name = "clang-format",
    srcs = ["bin/clang-format"],
)

filegroup(
    name = "git-clang-format",
    srcs = ["bin/git-clang-format"],
)

filegroup(
    name = "libclang",
    srcs = glob(
        [
            "lib/libclang.so",
            "lib/libclang.dylib",
        ],
        allow_empty = True,
    ),
)
