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
    _arch = "arch",
    _canonical_dir_path = "canonical_dir_path",
    _check_os_arch_keys = "check_os_arch_keys",
    _os = "os",
    _os_arch_pair = "os_arch_pair",
    _pkg_path_from_label = "pkg_path_from_label",
)
load(
    "//toolchain/internal:sysroot.bzl",
    _sysroot_path = "sysroot_path",
)
load("@rules_cc//cc:defs.bzl", _cc_toolchain = "cc_toolchain")

def _makevars_ld_flags(rctx, os):
    if os == "darwin":
        return ""

    # lld, as of LLVM 7, is experimental for Mach-O, so we use it only on linux.
    return "-fuse-ld=lld"

def _include_dirs_str(rctx, key):
    dirs = rctx.attr.cxx_builtin_include_directories.get(key)
    if not dirs:
        return ""
    return ("\n" + 12 * " ").join(["\"%s\"," % d for d in dirs])

def llvm_config_impl(rctx):
    _check_os_arch_keys(rctx.attr.toolchain_roots)
    _check_os_arch_keys(rctx.attr.sysroot)
    _check_os_arch_keys(rctx.attr.cxx_builtin_include_directories)

    os = _os(rctx)
    if os == "windows":
        rctx.file("BUILD.bazel")
        rctx.file("toolchains.bzl", """
def llvm_register_toolchains():
    pass
        """)
        return
    arch = _arch(rctx)

    key = _os_arch_pair(os, arch)
    toolchain_root = rctx.attr.toolchain_roots.get(key)
    if not toolchain_root:
        toolchain_root = rctx.attr.toolchain_roots.get("")
    if not toolchain_root:
        fail("LLVM toolchain root missing for ({}, {})", os, arch)

    # Check if the toolchain root is an absolute path.
    use_absolute_paths = rctx.attr.absolute_paths
    if toolchain_root[0] == "/" and (len(toolchain_root) == 1 or toolchain_root[1] != "/"):
        use_absolute_paths = True

    if use_absolute_paths:
        llvm_repo_label = Label(toolchain_root + ":BUILD.bazel")  # Exact target does not matter.
        llvm_repo_path = _canonical_dir_path(str(rctx.path(llvm_repo_label).dirname))
        config_repo_path = _canonical_dir_path(str(rctx.path("")))
        toolchain_path_prefix = llvm_repo_path
        tools_path_prefix = llvm_repo_path
        cc_wrapper_prefix = config_repo_path
    else:
        llvm_repo_path = _pkg_path_from_label(Label(toolchain_root + ":BUILD.bazel"))
        config_repo_path = "external/%s/" % rctx.name

        # tools can only be defined in a subdirectory of config_repo_path,
        # because their paths are relative to the package defining
        # cc_toolchain, and cannot contain '..'.
        # https://github.com/bazelbuild/bazel/issues/7746.  To work around
        # this, we symlink the llvm repo under the package so all tools (except
        # clang) can be called with normalized relative paths. For clang
        # however, using a path with symlinks interferes with the header file
        # inclusion validation checks, because clang frontend will infer the
        # InstalledDir to be the symlinked path, and will look for header files
        # in the symlinked path, but that seems to fail the inclusion
        # validation check. So we always use a cc_wrapper (which is called
        # through a normalized relative path), and then call clang with the not
        # symlinked path from the wrapper.
        rctx.symlink("../../" + llvm_repo_path, "llvm")
        toolchain_path_prefix = llvm_repo_path
        tools_path_prefix = "llvm/"
        cc_wrapper_prefix = ""

    sysroot_path, sysroot = _sysroot_path(rctx, os, arch)
    sysroot_label = "\"%s\"" % str(sysroot) if sysroot else ""

    cc_toolchains_str = (
        _llvm_filegroups_str(sysroot_label, toolchain_root, use_absolute_paths) +
        _cc_toolchain_str("cc-clang-k8-linux", "local_linux_k8", False, use_absolute_paths) +
        _cc_toolchain_str("cc-clang-aarch64-linux", "local_linux_aarch64", False, use_absolute_paths) +
        _cc_toolchain_str("cc-clang-darwin", "local_darwin", True, use_absolute_paths)
    )

    substitutions = {
        "%{toolchain_workspace_name}": rctx.name,
        "%{llvm_version}": rctx.attr.llvm_version,
        "%{bazel_version}": native.bazel_version,
        "%{toolchain_root}": toolchain_root,
        "%{toolchain_path_prefix}": toolchain_path_prefix,
        "%{tools_path_prefix}": tools_path_prefix,
        "%{cc_wrapper_prefix}": cc_wrapper_prefix,
        "%{sysroot_path}": sysroot_path,
        "%{sysroot_prefix}": "%sysroot%" if sysroot_path else "",
        "%{makevars_ld_flags}": _makevars_ld_flags(rctx, os),
        "%{k8_additional_cxx_builtin_include_directories}": _include_dirs_str(rctx, "linux-x86_64"),
        "%{aarch64_additional_cxx_builtin_include_directories}": _include_dirs_str(rctx, "linux-aarch64"),
        "%{darwin_additional_cxx_builtin_include_directories}": _include_dirs_str(rctx, "darwin-x86_64"),
        "%{cc_toolchains}": cc_toolchains_str,
    }

    rctx.template(
        "toolchains.bzl",
        Label("//toolchain:toolchains.bzl.tpl"),
        substitutions,
    )
    rctx.template(
        "cc_toolchain_config.bzl",
        Label("//toolchain:cc_toolchain_config.bzl.tpl"),
        substitutions,
    )
    rctx.template(
        "Makevars",
        Label("//toolchain:Makevars.tpl"),
        substitutions,
    )
    rctx.template(
        "BUILD.bazel",
        Label("//toolchain:BUILD.toolchain.tpl"),
        substitutions,
    )

    if os == "darwin":
        cc_wrapper_tpl = "//toolchain:osx_cc_wrapper.sh.tpl"
    else:
        cc_wrapper_tpl = "//toolchain:cc_wrapper.sh.tpl"
    rctx.template(
        "bin/cc_wrapper.sh",
        Label(cc_wrapper_tpl),
        substitutions,
    )

def _llvm_filegroups_str(sysroot_label, toolchain_root, use_absolute_paths):
    if use_absolute_paths:
        return ""

    return """
# LLVM distribution filegroup definitions that are used in cc_toolchain targets.

filegroup(
    name = "ar",
    srcs = ["{toolchain_root}:ar"],
)

filegroup(
    name = "as",
    srcs = ["{toolchain_root}:as"],
)

filegroup(
    name = "sysroot_components",
    srcs = [{sysroot_label}],
)

filegroup(
    name = "binutils_components",
    srcs = ["{toolchain_root}:bin"],
)

filegroup(
    name = "compiler_components",
    srcs = [
        "{toolchain_root}:clang",
        "{toolchain_root}:include",
        ":sysroot_components",
    ],
)

filegroup(
    name = "linker_components",
    srcs = [
        "{toolchain_root}:clang",
        "{toolchain_root}:ld",
        "{toolchain_root}:ar",
        "{toolchain_root}:lib",
        ":sysroot_components",
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
""".format(sysroot_label = sysroot_label, toolchain_root = toolchain_root)

def _cc_toolchain_str(name, toolchain_config, darwin, use_absolute_paths):
    supports_param_files = 0 if darwin else 1
    extra_files = ", \":llvm\", \":cc_wrapper\""

    if use_absolute_paths:
        template = """
# CC toolchain for {name} with absolute paths.

cc_toolchain(
    name = "{name}",
    all_files = ":empty",
    compiler_files = ":empty",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = {supports_param_files},
    toolchain_config = "{toolchain_config}",
)
"""
    else:
        template = """
# CC toolchain for {name}.

filegroup(name = "{name}-all-files", srcs = [":all_components"{extra_files}])
filegroup(name = "{name}-archiver-files", srcs = [":ar"{extra_files}])
filegroup(name = "{name}-assembler-files", srcs = [":as"{extra_files}])
filegroup(name = "{name}-compiler-files", srcs = [":compiler_components"{extra_files}])
filegroup(name = "{name}-linker-files", srcs = [":linker_components"{extra_files}])

cc_toolchain(
    name = "{name}",
    all_files = "{name}-all-files",
    ar_files = "{name}-archiver-files",
    as_files = "{name}-assembler-files",
    compiler_files = "{name}-compiler-files",
    dwp_files = ":dwp",
    linker_files = "{name}-linker-files",
    objcopy_files = ":objcopy",
    strip_files = ":empty",
    supports_param_files = {supports_param_files},
    toolchain_config = "{toolchain_config}",
)
"""

    return template.format(
        name = name,
        supports_param_files = supports_param_files,
        toolchain_config = toolchain_config,
        extra_files = extra_files,
    )
