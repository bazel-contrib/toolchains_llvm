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
    "//toolchain/internal:common.bzl",
    _supported_os_arch_keys = "supported_os_arch_keys",
)
load(
    "//toolchain/internal:configure.bzl",
    _llvm_config_impl = "llvm_config_impl",
)
load(
    "//toolchain/internal:repo.bzl",
    _llvm_repo_impl = "llvm_repo_impl",
)

_common_attrs = {
    "llvm_version": attr.string(
        mandatory = True,
        doc = "One of the supported versions of LLVM, e.g. 12.0.0",
    ),
}

_llvm_repo_attrs = dict(_common_attrs)
_llvm_repo_attrs.update({
    "distribution": attr.string(
        default = "auto",
        doc = ("LLVM pre-built binary distribution filename, must be one " +
               "listed on http://releases.llvm.org/download.html for the version " +
               "specified in the llvm_version attribute. A special value of " +
               "'auto' tries to detect the version based on host OS."),
    ),
    "llvm_mirror": attr.string(
        doc = "Base URL for an LLVM release mirror." +
              "\n\n" +
              "This mirror must follow the same structure as the official LLVM release " +
              "sources (`releases.llvm.org` for versions <= 9, `llvm/llvm-project` GitHub " +
              "releases for newer versions)." +
              "\n\n" +
              "If provided, this mirror will be given precedence over the official LLVM release " +
              "sources (see: " +
              "https://github.com/grailbio/bazel-toolchain/toolchain/internal/llvm_distributions.bzl).",
    ),
    "alternative_llvm_sources": attr.string_list(
        doc = "Patterns for alternative LLVM release sources. Unlike URLs specified for `llvm_mirror` " +
              "these do not have to follow the same structure as the official LLVM release sources." +
              "\n\n" +
              "Patterns may include `{llvm_version}` (which will be substituted for the full LLVM " +
              "version, i.e. 13.0.0) and `{basename}` (which will be replaced with the filename " +
              "used by the official LLVM release sources for a particular distribution; i.e. " +
              "`llvm-13.0.0-x86_64-linux-gnu-ubuntu-20.04.tar.xz`)." +
              "\n\n" +
              "As with `llvm_mirror`, these sources will take precedence over the official LLVM " +
              "release sources.",
    ),
    "netrc": attr.string(
        mandatory = False,
        doc = "Path to the netrc file for authenticated LLVM URL downloads.",
    ),
    "auth_patterns": attr.string_dict(
        mandatory = False,
        doc = "An optional dict mapping host names to custom authorization patterns.",
    ),
    "_llvm_release_name": attr.label(
        default = "//toolchain/tools:llvm_release_name.py",
        allow_single_file = True,
        doc = "Python module to output LLVM release name for the current OS.",
    ),
})

_llvm_config_attrs = dict(_common_attrs)
_llvm_config_attrs.update({
    "toolchain_roots": attr.string_dict(
        mandatory = True,
        # TODO: Ideally, we should be taking a filegroup label here instead of a package path, but
        # we ultimately need to subset the files to be more selective in what we include in the
        # sandbox for which operations, and it is not straightforward to subset a filegroup.
        doc = ("System or package path, for each host OS and arch pair you want to support " +
               "({}), ".format(", ".join(_supported_os_arch_keys())) +
               "to be used as the LLVM toolchain distributions. An empty key can be used to " +
               "specify a fallback default for all hosts, e.g. with the llvm_toolchain_repo rule. " +
               "If the value begins with exactly one forward slash '/', then the value is " +
               "assumed to be a system path and the toolchain is configured to use absolute " +
               "paths. Else, the value will be assumed to be a bazel package containing the " +
               "filegroup targets as in BUILD.llvm_repo."),
    ),
    "sysroot": attr.string_dict(
        mandatory = False,
        doc = ("System path or fileset, for each target OS and arch pair you want to support " +
               "({}), ".format(", ".join(_supported_os_arch_keys())) +
               "used to indicate the set of files that form the sysroot for the compiler. " +
               "If the value begins with exactly one forward slash '/', then the value is " +
               "assumed to be a system path. Else, the value will be assumed to be a label " +
               "containing the files and the sysroot path will be taken as the path to the " +
               "package of this label."),
    ),
    "cxx_builtin_include_directories": attr.string_list_dict(
        mandatory = False,
        doc = ("Additional builtin include directories to be added to the default system " +
               "directories, for each target OS and arch pair you want to support " +
               "({}); ".format(", ".join(_supported_os_arch_keys())) +
               "see documentation for bazel's create_cc_toolchain_config_info."),
    ),
    "absolute_paths": attr.bool(
        default = False,
        doc = "Use absolute paths in the toolchain. Avoids sandbox overhead.",
    ),
    "_cc_toolchain_config_bzl": attr.label(
        default = "//toolchain:cc_toolchain_config.bzl",
    ),
})

llvm = repository_rule(
    attrs = _llvm_repo_attrs,
    local = False,
    implementation = _llvm_repo_impl,
)

toolchain = repository_rule(
    attrs = _llvm_config_attrs,
    local = True,
    configure = True,
    implementation = _llvm_config_impl,
)

def llvm_toolchain(name, **kwargs):
    if not kwargs.get("toolchain_roots"):
        llvm_args = {
            k: v
            for k, v in kwargs.items()
            if (k not in _llvm_config_attrs.keys()) or (k in _common_attrs.keys())
        }
        llvm(name = name + "_llvm", **llvm_args)
        kwargs.update(toolchain_roots = {"": "@%s_llvm//" % name})

    toolchain_args = {
        k: v
        for k, v in kwargs.items()
        if (k not in _llvm_repo_attrs.keys()) or (k in _common_attrs.keys())
    }
    toolchain(name = name, **toolchain_args)
