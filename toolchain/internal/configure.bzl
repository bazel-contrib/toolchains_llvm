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

load("@bazel_skylib//lib:paths.bzl", "paths")
load(
    "//toolchain:aliases.bzl",
    _aliased_libs = "aliased_libs",
    _aliased_tools = "aliased_tools",
)
load(
    "//toolchain/internal:common.bzl",
    _arch = "arch",
    _canonical_dir_path = "canonical_dir_path",
    _check_os_arch_keys = "check_os_arch_keys",
    _exec_os_arch_dict_value = "exec_os_arch_dict_value",
    _is_absolute_path = "is_absolute_path",
    _list_to_string = "list_to_string",
    _os = "os",
    _os_arch_pair = "os_arch_pair",
    _os_bzl = "os_bzl",
    _pkg_path_from_label = "pkg_path_from_label",
    _supported_targets = "SUPPORTED_TARGETS",
    _toolchain_tools = "toolchain_tools",
)
load(
    "//toolchain/internal:sysroot.bzl",
    _default_sysroot_path = "default_sysroot_path",
    _sysroot_paths_dict = "sysroot_paths_dict",
)

# When bzlmod is enabled, canonical repos names have @@ in them, while under
# workspace builds, there is never a @@ in labels.
BZLMOD_ENABLED = "@@" in str(Label("//:unused"))

def _empty_repository(rctx):
    rctx.file("BUILD.bazel")
    rctx.file("toolchains.bzl", """\
def llvm_register_toolchains():
    pass
""")

def _join(path1, path2):
    if path1:
        return paths.join(path1, path2.lstrip("/"))
    else:
        return path2

def llvm_config_impl(rctx):
    _check_os_arch_keys(rctx.attr.sysroot)
    _check_os_arch_keys(rctx.attr.cxx_builtin_include_directories)

    os = _os(rctx)
    if os == "windows":
        _empty_repository(rctx)
        return
    arch = _arch(rctx)

    if not rctx.attr.toolchain_roots:
        toolchain_root = ("@" if BZLMOD_ENABLED else "") + "@%s_llvm//" % rctx.attr.name
    else:
        (_key, toolchain_root) = _exec_os_arch_dict_value(rctx, "toolchain_roots")

    if not toolchain_root:
        fail("LLVM toolchain root missing for ({}, {})".format(os, arch))
    (_key, llvm_version) = _exec_os_arch_dict_value(rctx, "llvm_versions")
    if not llvm_version:
        # LLVM version missing for (os, arch)
        _empty_repository(rctx)
        return
    use_absolute_paths_llvm = rctx.attr.absolute_paths
    use_absolute_paths_sysroot = use_absolute_paths_llvm

    # Check if the toolchain root is a system path.
    system_llvm = False
    if _is_absolute_path(toolchain_root):
        use_absolute_paths_llvm = True
        system_llvm = True

    # Paths for LLVM distribution:
    if system_llvm:
        llvm_dist_path_prefix = _canonical_dir_path(toolchain_root)
    else:
        llvm_dist_label = Label(toolchain_root + ":BUILD.bazel")  # Exact target does not matter.
        if use_absolute_paths_llvm:
            llvm_dist_path_prefix = _canonical_dir_path(str(rctx.path(llvm_dist_label).dirname))
        else:
            llvm_dist_path_prefix = _pkg_path_from_label(llvm_dist_label)

    if not use_absolute_paths_llvm:
        llvm_dist_rel_path = _canonical_dir_path("../../" + llvm_dist_path_prefix)
        llvm_dist_label_prefix = toolchain_root + ":"

        # tools can only be defined as absolute paths or in a subdirectory of
        # config_repo_path, because their paths are relative to the package
        # defining cc_toolchain, and cannot contain '..'.
        # https://github.com/bazelbuild/bazel/issues/7746.  To work around
        # this, we symlink the needed tools under the package so that they (except
        # clang) can be called with normalized relative paths. For clang
        # however, using a path with symlinks interferes with the header file
        # inclusion validation checks, because clang frontend will infer the
        # InstalledDir to be the symlinked path, and will look for header files
        # in the symlinked path, but that seems to fail the inclusion
        # validation check. So we always use a cc_wrapper (which is called
        # through a normalized relative path), and then call clang with the not
        # symlinked path from the wrapper.
        wrapper_bin_prefix = "bin/"
        tools_path_prefix = "bin/"
        tools = _toolchain_tools(os)
        for tool_name, symlink_name in tools.items():
            rctx.symlink(llvm_dist_rel_path + "bin/" + tool_name, tools_path_prefix + symlink_name)
        symlinked_tools_str = "".join([
            "\n" + (" " * 8) + "\"" + tools_path_prefix + symlink_name + "\","
            for symlink_name in tools.values()
        ])
    else:
        llvm_dist_rel_path = llvm_dist_path_prefix
        llvm_dist_label_prefix = llvm_dist_path_prefix

        # Path to individual tool binaries.
        # No symlinking necessary when using absolute paths.
        wrapper_bin_prefix = "bin/"
        tools_path_prefix = llvm_dist_path_prefix + "bin/"
        symlinked_tools_str = ""

    sysroot_paths_dict, sysroot_labels_dict = _sysroot_paths_dict(
        rctx,
        rctx.attr.sysroot,
        use_absolute_paths_sysroot,
    )

    workspace_name = rctx.name
    toolchain_info = struct(
        os = os,
        arch = arch,
        llvm_dist_label_prefix = llvm_dist_label_prefix,
        llvm_dist_path_prefix = llvm_dist_path_prefix,
        tools_path_prefix = tools_path_prefix,
        wrapper_bin_prefix = wrapper_bin_prefix,
        sysroot_paths_dict = sysroot_paths_dict,
        sysroot_labels_dict = sysroot_labels_dict,
        target_settings_dict = rctx.attr.target_settings,
        additional_include_dirs_dict = rctx.attr.cxx_builtin_include_directories,
        stdlib_dict = rctx.attr.stdlib,
        cxx_standard_dict = rctx.attr.cxx_standard,
        compile_flags_dict = rctx.attr.compile_flags,
        cxx_flags_dict = rctx.attr.cxx_flags,
        link_flags_dict = rctx.attr.link_flags,
        archive_flags_dict = rctx.attr.archive_flags,
        link_libs_dict = rctx.attr.link_libs,
        opt_compile_flags_dict = rctx.attr.opt_compile_flags,
        opt_link_flags_dict = rctx.attr.opt_link_flags,
        dbg_compile_flags_dict = rctx.attr.dbg_compile_flags,
        coverage_compile_flags_dict = rctx.attr.coverage_compile_flags,
        coverage_link_flags_dict = rctx.attr.coverage_link_flags,
        unfiltered_compile_flags_dict = rctx.attr.unfiltered_compile_flags,
        llvm_version = llvm_version,
        extra_compiler_files = rctx.attr.extra_compiler_files,
    )
    exec_dl_ext = "dylib" if os == "darwin" else "so"
    cc_toolchains_str, toolchain_labels_str = _cc_toolchains_str(
        rctx,
        workspace_name,
        toolchain_info,
        use_absolute_paths_llvm,
    )

    convenience_targets_str = _convenience_targets_str(
        rctx,
        use_absolute_paths_llvm,
        llvm_dist_rel_path,
        llvm_dist_label_prefix,
        exec_dl_ext,
    )

    # Convenience macro to register all generated toolchains.
    rctx.template(
        "toolchains.bzl",
        rctx.attr._toolchains_bzl_tpl,
        {
            "%{toolchain_labels}": toolchain_labels_str,
        },
    )

    # BUILD file with all the generated toolchain definitions.
    rctx.template(
        "BUILD.bazel",
        rctx.attr._build_toolchain_tpl,
        {
            "%{cc_toolchain_config_bzl}": str(rctx.attr._cc_toolchain_config_bzl),
            "%{cc_toolchains}": cc_toolchains_str,
            "%{symlinked_tools}": symlinked_tools_str,
            "%{wrapper_bin_prefix}": wrapper_bin_prefix,
            "%{convenience_targets}": convenience_targets_str,
        },
    )

    # CC wrapper script; see comments near the definition of `wrapper_bin_prefix`.
    if os == "darwin":
        cc_wrapper_tpl = rctx.attr._darwin_cc_wrapper_sh_tpl
    else:
        cc_wrapper_tpl = rctx.attr._cc_wrapper_sh_tpl
    rctx.template(
        "bin/cc_wrapper.sh",
        cc_wrapper_tpl,
        {
            "%{toolchain_path_prefix}": llvm_dist_path_prefix,
        },
    )

def _cc_toolchains_str(
        rctx,
        workspace_name,
        toolchain_info,
        use_absolute_paths_llvm):
    # Since all the toolchains rely on downloading the right LLVM toolchain for
    # the host architecture, we don't need to explicitly specify
    # `exec_compatible_with` attribute. If the host and execution platform are
    # not the same, then host auto-detection based LLVM download does not work
    # and the user has to explicitly specify the distribution of LLVM they
    # want.

    # Note that for cross-compiling, the toolchain configuration will need
    # appropriate sysroots. A recommended approach is to configure two
    # `llvm_toolchain` repos, one without sysroots (for easy single platform
    # builds) and register this one, and one with sysroots and provide
    # `--extra_toolchains` flag when cross-compiling.

    cc_toolchains_str = ""
    toolchain_names = []
    for (target_os, target_arch) in _supported_targets:
        suffix = "{}-{}".format(target_arch, target_os)
        cc_toolchain_str = _cc_toolchain_str(
            rctx,
            suffix,
            target_os,
            target_arch,
            toolchain_info,
            use_absolute_paths_llvm,
        )
        if cc_toolchain_str:
            cc_toolchains_str = cc_toolchains_str + cc_toolchain_str
            toolchain_name = "@{}//:cc-toolchain-{}".format(workspace_name, suffix)
            toolchain_names.append(toolchain_name)

    sep = ",\n" + " " * 8  # 2 tabs with tabstop=4.
    toolchain_labels_str = sep.join(["\"{}\"".format(d) for d in toolchain_names])
    return cc_toolchains_str, toolchain_labels_str

# Gets a value from the dict for the target pair, falling back to an empty
# key, if present.  Bazel 4.* doesn't support nested starlark functions, so
# we cannot simplify _dict_value() by defining it as a nested function.
def _dict_value(d, target_pair, default = None):
    return d.get(target_pair, d.get("", default))

def _cc_toolchain_str(
        rctx,
        suffix,
        target_os,
        target_arch,
        toolchain_info,
        use_absolute_paths_llvm):
    exec_os = toolchain_info.os
    exec_arch = toolchain_info.arch

    exec_os_bzl = _os_bzl(exec_os)
    target_os_bzl = _os_bzl(target_os)

    target_pair = _os_arch_pair(target_os, target_arch)

    sysroot_path = toolchain_info.sysroot_paths_dict.get(target_pair)
    sysroot_label = toolchain_info.sysroot_labels_dict.get(target_pair)
    if sysroot_label:
        sysroot_label_str = "\"%s\"" % str(sysroot_label)
    else:
        sysroot_label_str = ""

    if not sysroot_path:
        if exec_os == target_os and exec_arch == target_arch:
            # For darwin -> darwin, we can use the macOS SDK path.
            sysroot_path = _default_sysroot_path(rctx, exec_os)
        else:
            # We are trying to cross-compile without a sysroot, let's bail.
            # TODO: Are there situations where we can continue?
            return ""

    extra_files_str = "\":internal-use-files\""

    # C++ built-in include directories.
    # This contains both the includes shipped with the compiler as well as the sysroot (or host)
    # include directories. While Bazel's default undeclared inclusions check does not seem to be
    # triggered by header files under the execroot, we still include those paths here as they are
    # visible via the "built_in_include_directories" attribute of CcToolchainInfo as well as to keep
    # them in sync with the directories included in the system module map generated for the stricter
    # "layering_check" feature.
    toolchain_path_prefix = toolchain_info.llvm_dist_path_prefix
    llvm_version = toolchain_info.llvm_version
    major_llvm_version = int(llvm_version.split(".")[0])
    target_system_name = {
        "darwin-x86_64": "x86_64-apple-macosx",
        "darwin-aarch64": "aarch64-apple-macosx",
        "linux-aarch64": "aarch64-unknown-linux-gnu",
        "linux-x86_64": "x86_64-unknown-linux-gnu",
    }[target_pair]
    cxx_builtin_include_directories = [
        toolchain_path_prefix + "include/c++/v1",
        toolchain_path_prefix + "include/{}/c++/v1".format(target_system_name),
        toolchain_path_prefix + "lib/clang/{}/include".format(llvm_version),
        toolchain_path_prefix + "lib/clang/{}/share".format(llvm_version),
        toolchain_path_prefix + "lib64/clang/{}/include".format(llvm_version),
        toolchain_path_prefix + "lib/clang/{}/include".format(major_llvm_version),
        toolchain_path_prefix + "lib/clang/{}/share".format(major_llvm_version),
        toolchain_path_prefix + "lib64/clang/{}/include".format(major_llvm_version),
    ]

    sysroot_prefix = ""
    if sysroot_path:
        sysroot_prefix = "%sysroot%"
    if target_os == "linux":
        cxx_builtin_include_directories.extend([
            _join(sysroot_prefix, "/include"),
            _join(sysroot_prefix, "/usr/include"),
            _join(sysroot_prefix, "/usr/local/include"),
        ])
    elif target_os == "darwin":
        cxx_builtin_include_directories.extend([
            _join(sysroot_prefix, "/usr/include"),
            _join(sysroot_prefix, "/System/Library/Frameworks"),
        ])
    else:
        fail("Unreachable")

    cxx_builtin_include_directories.extend(toolchain_info.additional_include_dirs_dict.get(target_pair, []))

    template = """
# CC toolchain for cc-clang-{suffix}.

cc_toolchain_config(
    name = "local-{suffix}",
    exec_arch = "{exec_arch}",
    exec_os = "{exec_os}",
    target_arch = "{target_arch}",
    target_os = "{target_os}",
    target_system_name = "{target_system_name}",
    toolchain_path_prefix = "{llvm_dist_path_prefix}",
    tools_path_prefix = "{tools_path_prefix}",
    wrapper_bin_prefix = "{wrapper_bin_prefix}",
    compiler_configuration = {{
      "sysroot_path": "{sysroot_path}",
      "stdlib": "{stdlib}",
      "cxx_standard": "{cxx_standard}",
      "compile_flags": {compile_flags},
      "cxx_flags": {cxx_flags},
      "link_flags": {link_flags},
      "archive_flags": {archive_flags},
      "link_libs": {link_libs},
      "opt_compile_flags": {opt_compile_flags},
      "opt_link_flags": {opt_link_flags},
      "dbg_compile_flags": {dbg_compile_flags},
      "coverage_compile_flags": {coverage_compile_flags},
      "coverage_link_flags": {coverage_link_flags},
      "unfiltered_compile_flags": {unfiltered_compile_flags},
    }},
    cxx_builtin_include_directories = {cxx_builtin_include_directories},
)

toolchain(
    name = "cc-toolchain-{suffix}",
    exec_compatible_with = [
        "@platforms//cpu:{exec_arch}",
        "@platforms//os:{exec_os_bzl}",
    ],
    target_compatible_with = [
        "@platforms//cpu:{target_arch}",
        "@platforms//os:{target_os_bzl}",
    ],
    target_settings = {target_settings},
    toolchain = ":cc-clang-{suffix}",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)
"""

    template = template + """
filegroup(
    name = "sysroot-components-{suffix}",
    srcs = [{sysroot_label_str}],
)
"""

    if use_absolute_paths_llvm:
        template = template + """
filegroup(
    name = "compiler-components-{suffix}",
    srcs = [
        ":sysroot-components-{suffix}",
        {extra_compiler_files}
    ],
)

filegroup(
    name = "linker-components-{suffix}",
    srcs = [":sysroot-components-{suffix}"],
)

filegroup(
    name = "all-components-{suffix}",
    srcs = [
        ":compiler-components-{suffix}",
        ":linker-components-{suffix}",
    ],
)

filegroup(name = "all-files-{suffix}", srcs = [":all-components-{suffix}", {extra_files_str}])
filegroup(name = "archiver-files-{suffix}", srcs = [{extra_files_str}])
filegroup(name = "assembler-files-{suffix}", srcs = [{extra_files_str}])
filegroup(name = "compiler-files-{suffix}", srcs = [":compiler-components-{suffix}", {extra_files_str}])
filegroup(name = "dwp-files-{suffix}", srcs = [{extra_files_str}])
filegroup(name = "linker-files-{suffix}", srcs = [":linker-components-{suffix}", {extra_files_str}])
filegroup(name = "objcopy-files-{suffix}", srcs = [{extra_files_str}])
filegroup(name = "strip-files-{suffix}", srcs = [{extra_files_str}])
"""
    else:
        template = template + """
filegroup(
    name = "compiler-components-{suffix}",
    srcs = [
        "{llvm_dist_label_prefix}clang",
        "{llvm_dist_label_prefix}include",
        ":sysroot-components-{suffix}",
        {extra_compiler_files}
    ],
)

filegroup(
    name = "linker-components-{suffix}",
    srcs = [
        "{llvm_dist_label_prefix}clang",
        "{llvm_dist_label_prefix}ld",
        "{llvm_dist_label_prefix}ar",
        "{llvm_dist_label_prefix}lib",
        ":sysroot-components-{suffix}",
    ],
)

filegroup(
    name = "all-components-{suffix}",
    srcs = [
        "{llvm_dist_label_prefix}bin",
        ":compiler-components-{suffix}",
        ":linker-components-{suffix}",
    ],
)

filegroup(name = "all-files-{suffix}", srcs = [":all-components-{suffix}", {extra_files_str}])
filegroup(name = "archiver-files-{suffix}", srcs = ["{llvm_dist_label_prefix}ar", {extra_files_str}])
filegroup(name = "assembler-files-{suffix}", srcs = ["{llvm_dist_label_prefix}as", {extra_files_str}])
filegroup(name = "compiler-files-{suffix}", srcs = [":compiler-components-{suffix}", {extra_files_str}])
filegroup(name = "dwp-files-{suffix}", srcs = ["{llvm_dist_label_prefix}dwp", {extra_files_str}])
filegroup(name = "linker-files-{suffix}", srcs = [":linker-components-{suffix}", {extra_files_str}])
filegroup(name = "objcopy-files-{suffix}", srcs = ["{llvm_dist_label_prefix}objcopy", {extra_files_str}])
filegroup(name = "strip-files-{suffix}", srcs = ["{llvm_dist_label_prefix}strip", {extra_files_str}])
"""

    template = template + """
filegroup(
    name = "include-components-{suffix}",
    srcs = [
        ":compiler-components-{suffix}",
        ":sysroot-components-{suffix}",
    ],
)

system_module_map(
    name = "module-{suffix}",
    cxx_builtin_include_files = ":include-components-{suffix}",
    cxx_builtin_include_directories = {cxx_builtin_include_directories},
    sysroot_path = "{sysroot_path}",
)

cc_toolchain(
    name = "cc-clang-{suffix}",
    all_files = "all-files-{suffix}",
    ar_files = "archiver-files-{suffix}",
    as_files = "assembler-files-{suffix}",
    compiler_files = "compiler-files-{suffix}",
    dwp_files = "dwp-files-{suffix}",
    linker_files = "linker-files-{suffix}",
    objcopy_files = "objcopy-files-{suffix}",
    strip_files = "strip-files-{suffix}",
    toolchain_config = "local-{suffix}",
    module_map = "module-{suffix}",
)
"""

    return template.format(
        suffix = suffix,
        target_os = target_os,
        target_arch = target_arch,
        exec_os = exec_os,
        exec_arch = exec_arch,
        target_settings = _list_to_string(_dict_value(toolchain_info.target_settings_dict, target_pair)),
        target_os_bzl = target_os_bzl,
        target_system_name = target_system_name,
        exec_os_bzl = exec_os_bzl,
        llvm_dist_label_prefix = toolchain_info.llvm_dist_label_prefix,
        llvm_dist_path_prefix = toolchain_info.llvm_dist_path_prefix,
        tools_path_prefix = toolchain_info.tools_path_prefix,
        wrapper_bin_prefix = toolchain_info.wrapper_bin_prefix,
        sysroot_label_str = sysroot_label_str,
        sysroot_path = sysroot_path,
        stdlib = _dict_value(toolchain_info.stdlib_dict, target_pair, "builtin-libc++"),
        cxx_standard = _dict_value(toolchain_info.cxx_standard_dict, target_pair, "c++17"),
        compile_flags = _list_to_string(_dict_value(toolchain_info.compile_flags_dict, target_pair)),
        cxx_flags = _list_to_string(_dict_value(toolchain_info.cxx_flags_dict, target_pair)),
        link_flags = _list_to_string(_dict_value(toolchain_info.link_flags_dict, target_pair)),
        archive_flags = _list_to_string(_dict_value(toolchain_info.archive_flags_dict, target_pair)),
        link_libs = _list_to_string(_dict_value(toolchain_info.link_libs_dict, target_pair)),
        opt_compile_flags = _list_to_string(_dict_value(toolchain_info.opt_compile_flags_dict, target_pair)),
        opt_link_flags = _list_to_string(_dict_value(toolchain_info.opt_link_flags_dict, target_pair)),
        dbg_compile_flags = _list_to_string(_dict_value(toolchain_info.dbg_compile_flags_dict, target_pair)),
        coverage_compile_flags = _list_to_string(_dict_value(toolchain_info.coverage_compile_flags_dict, target_pair)),
        coverage_link_flags = _list_to_string(_dict_value(toolchain_info.coverage_link_flags_dict, target_pair)),
        unfiltered_compile_flags = _list_to_string(_dict_value(toolchain_info.unfiltered_compile_flags_dict, target_pair)),
        extra_files_str = extra_files_str,
        cxx_builtin_include_directories = _list_to_string([
            # Filter out non-existing directories with absolute paths as they
            # result in a -Wincomplete-umbrella warning when mentioned in the
            # system module map.
            dir
            for dir in cxx_builtin_include_directories
            if _is_hermetic_or_exists(rctx, dir, sysroot_path)
        ]),
        extra_compiler_files = ("\"%s\"," % str(toolchain_info.extra_compiler_files)) if toolchain_info.extra_compiler_files else "",
    )

def _convenience_targets_str(rctx, use_absolute_paths, llvm_dist_rel_path, llvm_dist_label_prefix, exec_dl_ext):
    if use_absolute_paths:
        llvm_dist_label_prefix = ":"
        filenames = []
        for libname in _aliased_libs:
            filename = "lib/{}.{}".format(libname, exec_dl_ext)
            filenames.append(filename)
        for toolname in _aliased_tools:
            filename = "bin/{}".format(toolname)
            filenames.append(filename)

        for filename in filenames:
            rctx.symlink(llvm_dist_rel_path + filename, filename)

    lib_target_strs = []
    for name in _aliased_libs:
        template = """
cc_import(
    name = "{name}",
    shared_library = "{{llvm_dist_label_prefix}}lib/lib{name}.{{exec_dl_ext}}",
)""".format(name = name)
        lib_target_strs.append(template)

    tool_target_strs = []
    for name in _aliased_tools:
        template = """
native_binary(
    name = "{name}",
    out = "{name}",
    src = "{{llvm_dist_label_prefix}}bin/{name}",
)""".format(name = name)
        tool_target_strs.append(template)

    return "\n".join(lib_target_strs + tool_target_strs).format(
        llvm_dist_label_prefix = llvm_dist_label_prefix,
        exec_dl_ext = exec_dl_ext,
    )

def _is_hermetic_or_exists(rctx, path, sysroot_path):
    path = path.replace("%sysroot%", sysroot_path).replace("//", "/")
    if not path.startswith("/"):
        return True
    return rctx.path(path).exists
