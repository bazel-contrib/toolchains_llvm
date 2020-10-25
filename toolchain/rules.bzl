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

load(
    "//toolchain/internal:configure.bzl",
    _conditional_cc_toolchain = "conditional_cc_toolchain",
    _llvm_toolchain_impl = "llvm_toolchain_impl",
)

# Symbols exported for public visibility.
conditional_cc_toolchain = _conditional_cc_toolchain

llvm_toolchain = repository_rule(
    attrs = {
        "llvm_version": attr.string(
            default = "6.0.0",
            doc = "One of the supported versions of LLVM.",
        ),
        "distribution": attr.string(
            default = "auto",
            doc = ("LLVM pre-built binary distribution filename, must be one " +
                   "listed on http://releases.llvm.org/download.html for the version " +
                   "specified in the llvm_version attribute. A special value of " +
                   "'auto' tries to detect the version based on host OS."),
        ),
        "sysroot": attr.string_dict(
            mandatory = False,
            doc = ("System path or fileset for each OS type (linux and darwin) used to indicate " +
                   "the set of files that form the sysroot for the compiler. If the value begins " +
                   "with exactly one forward slash '/', then the value is assumed to be a system " +
                   "path. Else, the value will be assumed to be a label containing the files and " +
                   "the sysroot path will be taken as the path to the package of this label."),
        ),
        "cxx_builtin_include_directories": attr.string_list_dict(
            mandatory = False,
            doc = ("Additional builtin include directories to be added to the default system " +
                   "directories, keyed by the CPU type (e.g. k8 or darwin). See documentation " +
                   "for bazel's create_cc_toolchain_config_info."),
        ),
        "llvm_mirror": attr.string(
            doc = "Mirror base for LLVM binaries if using the pre-configured URLs.",
        ),
        "absolute_paths": attr.bool(
            default = False,
            doc = "Use absolute paths in the toolchain. Avoids sandbox overhead.",
        ),
        "_llvm_release_name": attr.label(
            default = "//toolchain/tools:llvm_release_name.py",
            allow_single_file = True,
            doc = "Python module to output LLVM release name for the current OS.",
        ),
        # Following attributes are needed only when using a non-standard URL scheme.
        "urls": attr.string_list_dict(
            mandatory = False,
            doc = "URLs for each OS type (linux and darwin) if not using the pre-configured URLs.",
        ),
        "sha256": attr.string_dict(
            mandatory = False,
            doc = "sha256 of the archive for each OS type.",
        ),
        "strip_prefix": attr.string_dict(
            mandatory = False,
            doc = "Path prefix to strip from the extracted files.",
        ),
    },
    local = False,
    implementation = _llvm_toolchain_impl,
)
