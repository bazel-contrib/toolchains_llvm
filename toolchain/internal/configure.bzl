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
    "@com_grail_bazel_toolchain//toolchain/internal:llvm_distributions.bzl",
    _download_llvm = "download_llvm",
    _download_llvm_preconfigured = "download_llvm_preconfigured",
)
load(
    "@com_grail_bazel_toolchain//toolchain/internal:sysroot.bzl",
    _sysroot_path = "sysroot_path",
)

def _makevars_ld_flags(rctx):
    if rctx.os.name == "mac os x":
        return ""

    # lld, as of LLVM 7, is experimental for Mach-O, so we use it only on linux.
    return "-fuse-ld=lld"

def llvm_toolchain_impl(rctx):
    repo_path = str(rctx.path(""))
    relative_path_prefix = "external/%s/" % rctx.name
    if rctx.attr.absolute_paths:
        toolchain_path_prefix = (repo_path + "/")
    else:
        toolchain_path_prefix = relative_path_prefix

    sysroot_path, sysroot = _sysroot_path(rctx)
    substitutions = {
        "%{llvm_version}": rctx.attr.llvm_version,
        "%{toolchain_path_prefix}": toolchain_path_prefix,
        "%{tools_path_prefix}": (repo_path + "/") if rctx.attr.absolute_paths else "",
        "%{debug_toolchain_path_prefix}": relative_path_prefix,
        "%{sysroot_path}": sysroot_path,
        "%{sysroot_prefix}": "%sysroot%" if sysroot_path else "",
        "%{sysroot_label}": "\"%s\"" % str(sysroot) if sysroot else "",
        "%{absolute_paths}": "True" if rctx.attr.absolute_paths else "False",
        "%{makevars_ld_flags}": _makevars_ld_flags(rctx),
    }

    rctx.template(
        "CROSSTOOL",
        Label("@com_grail_bazel_toolchain//toolchain:CROSSTOOL.tpl"),
        substitutions,
    )
    rctx.template(
        "bin/cc_wrapper.sh",  # Co-located with the linker to help rules_go.
        Label("@com_grail_bazel_toolchain//toolchain:cc_wrapper.sh.tpl"),
        substitutions,
    )
    rctx.template(
        "Makevars",
        Label("@com_grail_bazel_toolchain//toolchain:Makevars.tpl"),
        substitutions,
    )
    rctx.template(
        "BUILD",
        Label("@com_grail_bazel_toolchain//toolchain:BUILD.tpl"),
        substitutions,
    )

    rctx.symlink("/usr/bin/ar", "bin/ar")  # For GoLink.

    # For GoCompile on macOS; compiler path is set from linker path.
    # It also helps clang driver sometimes for the linker to be colocated with the compiler.
    rctx.symlink("/usr/bin/ld", "bin/ld")
    if rctx.os.name == "linux":
        rctx.symlink("/usr/bin/ld.gold", "bin/ld.gold")
    else:
        # Add dummy file for non-linux so we don't have to put conditional logic in BUILD.
        rctx.file("bin/ld.gold")

    # Repository implementation functions can be restarted, keep expensive ops at the end.
    if not _download_llvm(rctx):
        _download_llvm_preconfigured(rctx)

def conditional_cc_toolchain(name, cpu, darwin, absolute_paths = False):
    # Toolchain macro for BUILD file to use conditional logic.

    if absolute_paths:
        native.cc_toolchain(
            name = name,
            toolchain_identifier = "clang-darwin" if darwin else "clang-linux",
            cpu = cpu,
            all_files = ":empty",
            compiler_files = ":empty",
            dwp_files = ":empty",
            linker_files = ":empty",
            objcopy_files = ":empty",
            strip_files = ":empty",
            supports_param_files = 0 if darwin else 1,
        )
    else:
        extra_files = [":cc_wrapper"] if darwin else []
        native.filegroup(name = name + "-all-files", srcs = [":all_components"] + extra_files)
        native.filegroup(name = name + "-compiler-files", srcs = [":compiler_components"] + extra_files)
        native.filegroup(name = name + "-linker-files", srcs = [":linker_components"] + extra_files)
        native.cc_toolchain(
            name = name,
            toolchain_identifier = "clang-darwin" if darwin else "clang-linux",
            cpu = cpu,
            all_files = name + "-all-files",
            compiler_files = name + "-compiler-files",
            dwp_files = ":empty",
            linker_files = name + "-linker-files",
            objcopy_files = ":objcopy",
            strip_files = ":empty",
            supports_param_files = 0 if darwin else 1,
        )
