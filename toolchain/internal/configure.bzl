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

load("@bazel_features//:features.bzl", "bazel_features")
load("@helly25_bzl//bzl/paths:paths.bzl", "paths")
load(
    "//toolchain:aliases.bzl",
    _aliased_libs = "aliased_libs",
    _aliased_tools = "aliased_tools",
)
load(
    "//toolchain/internal:common.bzl",
    _arch = "arch",
    _arch_from_rctx = "arch_from_rctx",
    _canonical_dir_path = "canonical_dir_path",
    _check_os_arch_keys = "check_os_arch_keys",
    _exec_os_arch_dict_value = "exec_os_arch_dict_value",
    _is_absolute_path = "is_absolute_path",
    _is_standalone_arch = "is_standalone_arch",
    _list_to_string = "list_to_string",
    _os = "os",
    _os_arch_pair = "os_arch_pair",
    _os_bzl = "os_bzl",
    _os_from_rctx = "os_from_rctx",
    _pkg_path_from_label = "pkg_path_from_label",
    _supported_no_sysroot_targets = "SUPPORTED_NO_SYSROOT_TARGETS",
    _supported_targets = "SUPPORTED_TARGETS",
    _toolchain_tools = "toolchain_tools",
)
load(
    "//toolchain/internal:llvm_distributions.bzl",
    _required_llvm_version_rctx = "required_llvm_version_rctx",
)
load(
    "//toolchain/internal:sysroot.bzl",
    _default_sysroot_path = "default_sysroot_path",
    _sysroot_paths_dict = "sysroot_paths_dict",
)

# When bzlmod is enabled, canonical repos names have @@ in them, while under
# workspace builds, there is never a @@ in labels.
BZLMOD_ENABLED = "@@" in str(Label("//:unused"))

def _detect_gcc_cxx_headers(rctx, sysroot_path, target_system_name):
    """Detect GCC C++ header directories in a sysroot.

    When using libstdc++ with a sysroot, clang needs to know where the GCC C++
    headers are located. This function auto-detects these paths by scanning
    the sysroot for installed GCC versions.

    Args:
        rctx: Repository context.
        sysroot_path: Path to the sysroot (absolute or relative).
        target_system_name: Target triple (e.g., x86_64-unknown-linux-gnu).

    Returns:
        List of C++ include directory paths relative to the sysroot root.
    """
    include_dirs = []

    # For non-absolute paths (Bazel labels), we can't inspect the filesystem
    # during repository rule execution. Return empty and let users specify
    # additional include dirs manually via cxx_builtin_include_directories.
    if not _is_absolute_path(sysroot_path):
        return include_dirs

    # Extract the GNU target triple from target_system_name
    # e.g., "x86_64-unknown-linux-gnu" -> "x86_64-linux-gnu"
    parts = target_system_name.split("-")
    if len(parts) >= 3:
        # Common GNU triple format: arch-linux-gnu or arch-linux-gnueabihf
        gnu_triple = parts[0] + "-linux-" + parts[-1]
    else:
        gnu_triple = target_system_name

    # Check for GCC C++ headers in common locations
    # Modern distros (Debian 10+, Ubuntu 18.04+): /usr/include/c++/<version>
    cxx_include_path = rctx.path(paths.join(sysroot_path, "usr/include/c++"))
    if cxx_include_path.exists:
        # Find GCC version directories (e.g., "14", "13", "12")
        for entry in cxx_include_path.readdir():
            version = entry.basename

            # Add main C++ headers
            include_dirs.append(paths.join("/usr/include/c++", version))

            # Add target-specific headers (for multi-arch)
            include_dirs.append(paths.join("/usr/include", gnu_triple, "c++", version))

            # Add backward compatibility headers
            include_dirs.append(paths.join("/usr/include/c++", version, "backward"))

    # Also check traditional GCC installation path: /usr/lib/gcc/<triple>/<version>/...
    # This is the layout used by older distros and Chromium sysroots
    gcc_lib_path = rctx.path(paths.join(sysroot_path, "usr/lib/gcc", gnu_triple))
    if gcc_lib_path.exists:
        for entry in gcc_lib_path.readdir():
            version = entry.basename

            # Traditional GCC include path structure uses relative paths from gcc lib dir
            # e.g., /usr/lib/gcc/x86_64-linux-gnu/6/../../../../include/c++/6
            # which resolves to /usr/include/c++/6
            base = paths.join("/usr/lib/gcc", gnu_triple, version)
            include_dirs.append(paths.join(base, "../../../../include/c++", version))
            include_dirs.append(paths.join(base, "../../../../include", gnu_triple, "c++", version))
            include_dirs.append(paths.join(base, "../../../../include/c++", version, "backward"))

    return include_dirs

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

def _is_absolute(path):
    return path[0] == "/" and (len(path) == 1 or path[1] != "/")

def llvm_config_impl(rctx):
    # When `target_toolchain_roots` is not explicitly set, default it to
    # `toolchain_roots` so the per-target dict lookups in `cc_toolchain_config_info`
    # still find the right roots. Keeping this in the rule impl (rather than the
    # macro) lets us tell "unset" apart from "explicitly set".
    target_toolchain_roots = rctx.attr.target_toolchain_roots or rctx.attr.toolchain_roots

    _check_os_arch_keys(rctx.attr.toolchain_roots)
    _check_os_arch_keys(target_toolchain_roots)
    _check_os_arch_keys(rctx.attr.sysroot)
    _check_os_arch_keys(rctx.attr.cxx_builtin_include_directories)
    _check_os_arch_keys(rctx.attr.extra_exec_compatible_with)
    _check_os_arch_keys(rctx.attr.extra_target_compatible_with)
    _check_os_arch_keys(rctx.attr.stdlib)

    os = _os(rctx)
    if os == "windows":
        _empty_repository(rctx)
        return None
    arch = _arch(rctx)

    if not rctx.attr.toolchain_roots:
        toolchain_root = ("@" if BZLMOD_ENABLED else "") + "@%s_llvm//" % rctx.attr.name
    else:
        _, toolchain_root = _exec_os_arch_dict_value(rctx, "toolchain_roots")

    if not toolchain_root:
        fail("LLVM toolchain root missing for ({}, {})".format(os, arch))
    llvm_version = _required_llvm_version_rctx(rctx)
    if not llvm_version:
        # LLVM version missing for (os, arch)
        _empty_repository(rctx)
        return None
    use_absolute_paths_llvm = rctx.attr.absolute_paths
    use_absolute_paths_sysroot = use_absolute_paths_llvm

    # Check if the toolchain root is a system path.
    system_llvm = _is_absolute_path(toolchain_root)
    if system_llvm:
        use_absolute_paths_llvm = True

    # Make sure the toolchain root and target toolchain roots either are both absolute or both not.
    for target_toolchain_root in target_toolchain_roots.values():
        if _is_absolute(toolchain_root) != _is_absolute(target_toolchain_root):
            fail("Host and target toolchain roots must both be absolute or not")

    # Compute the repo paths for each of the target toolchains.
    target_llvm_repo_paths = {}
    toolchain_path_prefix = None
    if use_absolute_paths_llvm:
        if _is_absolute_path(toolchain_root):
            toolchain_path_prefix = _canonical_dir_path(toolchain_root)
        else:
            llvm_repo_label = Label(toolchain_root + ":BUILD.bazel")  # Exact target does not matter.
            toolchain_path_prefix = _canonical_dir_path(str(rctx.path(llvm_repo_label).dirname))
        for a_key in target_toolchain_roots:
            target_toolchain_root = target_toolchain_roots[a_key]
            if _is_absolute_path(target_toolchain_root):
                target_llvm_repo_paths[a_key] = _canonical_dir_path(target_toolchain_root)
            else:
                target_llvm_repo_label = Label(target_toolchain_root + ":BUILD.bazel")
                target_llvm_repo_paths[a_key] = _canonical_dir_path(str(rctx.path(target_llvm_repo_label).dirname))
    else:
        for a_key in target_toolchain_roots:
            target_llvm_repo_label = Label(target_toolchain_roots[a_key] + ":BUILD.bazel")
            target_llvm_repo_paths[a_key] = _pkg_path_from_label(target_llvm_repo_label)

    # Paths for LLVM distribution:
    if system_llvm:
        llvm_dist_path_prefix = _canonical_dir_path(toolchain_root)
    else:
        llvm_dist_label = Label(toolchain_root + ":BUILD.bazel")  # Exact target does not matter.
        if use_absolute_paths_llvm:
            llvm_dist_path_prefix = _canonical_dir_path(str(rctx.path(llvm_dist_label).dirname))
        else:
            llvm_dist_path_prefix = _pkg_path_from_label(llvm_dist_label)

    if not toolchain_path_prefix:
        toolchain_path_prefix = llvm_dist_path_prefix

    if not use_absolute_paths_llvm:
        llvm_dist_rel_path = _canonical_dir_path(paths.join("../..", llvm_dist_path_prefix))
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
        # Probe each binary for existence
        tools = {}
        for tool in _toolchain_tools(os).items():
            if rctx.path(llvm_dist_rel_path + "bin/" + tool[0]).exists:
                tools.update([tool])

        for tool_name, symlink_name in tools.items():
            rctx.symlink(paths.join(llvm_dist_rel_path, "bin", tool_name), paths.join(tools_path_prefix, symlink_name))
        symlinked_tools_str = "".join([
            "\n" + (" " * 8) + "\"" + paths.join(tools_path_prefix, symlink_name) + "\","
            for symlink_name in tools.values()
        ])
    else:
        llvm_dist_rel_path = llvm_dist_path_prefix
        llvm_dist_label_prefix = llvm_dist_path_prefix

        # Path to individual tool binaries.
        # No symlinking necessary when using absolute paths.
        wrapper_bin_prefix = "bin/"
        tools_path_prefix = paths.ensure_trailing_slash(paths.join(llvm_dist_path_prefix, "bin"))
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
        multiarch_dict = rctx.attr.multiarch,
        cxx_include_layout_dict = rctx.attr.cxx_include_layout,
        target_settings_dict = rctx.attr.target_settings,
        additional_include_dirs_dict = rctx.attr.cxx_builtin_include_directories,
        stdlib_dict = rctx.attr.stdlib,
        cxx_standard_dict = rctx.attr.cxx_standard,
        compile_flags_dict = rctx.attr.compile_flags,
        conly_flags_dict = rctx.attr.conly_flags,
        cxx_flags_dict = rctx.attr.cxx_flags,
        link_flags_dict = rctx.attr.link_flags,
        archive_flags_dict = rctx.attr.archive_flags,
        link_libs_dict = rctx.attr.link_libs,
        fastbuild_compile_flags_dict = rctx.attr.fastbuild_compile_flags,
        opt_compile_flags_dict = rctx.attr.opt_compile_flags,
        opt_link_flags_dict = rctx.attr.opt_link_flags,
        dbg_compile_flags_dict = rctx.attr.dbg_compile_flags,
        coverage_compile_flags_dict = rctx.attr.coverage_compile_flags,
        coverage_link_flags_dict = rctx.attr.coverage_link_flags,
        target_toolchain_path_prefixes_dict = target_llvm_repo_paths,
        target_toolchain_roots_dict = target_toolchain_roots,
        toolchain_path_prefix = toolchain_path_prefix,
        toolchain_root = toolchain_root,
        unfiltered_compile_flags_dict = rctx.attr.unfiltered_compile_flags,
        llvm_version = llvm_version,
        extra_compiler_files = rctx.attr.extra_compiler_files,
        extra_linker_files = rctx.attr.extra_linker_files,
        extra_compiler_files_dict = rctx.attr.extra_compiler_files_dict,
        extra_linker_files_dict = rctx.attr.extra_linker_files_dict,
        extra_exec_compatible_with = rctx.attr.extra_exec_compatible_with,
        extra_target_compatible_with = rctx.attr.extra_target_compatible_with,
        extra_compile_flags_dict = rctx.attr.extra_compile_flags,
        extra_cxx_flags_dict = rctx.attr.extra_cxx_flags,
        extra_link_flags_dict = rctx.attr.extra_link_flags,
        extra_archive_flags_dict = rctx.attr.extra_archive_flags,
        extra_link_libs_dict = rctx.attr.extra_link_libs,
        extra_opt_compile_flags_dict = rctx.attr.extra_opt_compile_flags,
        extra_opt_link_flags_dict = rctx.attr.extra_opt_link_flags,
        extra_dbg_compile_flags_dict = rctx.attr.extra_dbg_compile_flags,
        extra_coverage_compile_flags_dict = rctx.attr.extra_coverage_compile_flags,
        extra_coverage_link_flags_dict = rctx.attr.extra_coverage_link_flags,
        extra_unfiltered_compile_flags_dict = rctx.attr.extra_unfiltered_compile_flags,
        extra_known_features = rctx.attr.extra_known_features,
        extra_enabled_features = rctx.attr.extra_enabled_features,
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
            "%{tools_dir}": wrapper_bin_prefix.removesuffix("/"),
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

    rctx.file(
        "redacted_dates.h",
        "#define __DATE__      \"redacted\"\n" +
        "#define __TIME__      \"redacted\"\n" +
        "#define __TIMESTAMP__ \"redacted\"\n",
    )

    if hasattr(rctx, "repo_metadata"):
        return rctx.repo_metadata(reproducible = True)
    else:
        return None

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
        if _is_standalone_arch(target_os, target_arch):
            suffix = target_arch
        else:
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
        sysroot_label_str = repr(str(sysroot_label))
    else:
        sysroot_label_str = ""

    _extra_compiler_label = (
        toolchain_info.extra_compiler_files_dict.get(target_pair) or
        toolchain_info.extra_compiler_files_dict.get("") or
        (str(toolchain_info.extra_compiler_files) if toolchain_info.extra_compiler_files else None)
    )
    _extra_linker_label = (
        toolchain_info.extra_linker_files_dict.get(target_pair) or
        toolchain_info.extra_linker_files_dict.get("") or
        (str(toolchain_info.extra_linker_files) if toolchain_info.extra_linker_files else None)
    )

    if not sysroot_path:
        if exec_os == target_os and exec_arch == target_arch:
            # For darwin -> darwin, we can use the macOS SDK path.
            sysroot_path = _default_sysroot_path(rctx, exec_os)
        elif (target_os, target_arch) in _supported_no_sysroot_targets:
            sysroot_path = ""
        else:
            # We are trying to cross-compile without a sysroot, let's bail.
            # TODO: Are there other situations where we can continue?
            return ""

    # Normalize the sysroot to a canonical directory path ending in "/", the
    # same convention used by the `*_path_prefix` arguments. cc_toolchain_config
    # concatenates relative subpaths (no leading slash) and asserts the
    # convention, rather than silently producing malformed flags.
    if sysroot_path:
        sysroot_path = _canonical_dir_path(sysroot_path)

    extra_files_str = repr(":internal-use-tools" if bazel_features.rules.merkle_cache_v2 else ":internal-use-tools-legacy")

    # C++ built-in include directories.
    # This contains both the includes shipped with the compiler as well as the sysroot (or host)
    # include directories. While Bazel's default undeclared inclusions check does not seem to be
    # triggered by header files under the execroot, we still include those paths here as they are
    # visible via the "built_in_include_directories" attribute of CcToolchainInfo as well as to keep
    # them in sync with the directories included in the system module map generated for the stricter
    # "layering_check" feature.
    llvm_version = toolchain_info.llvm_version
    major_llvm_version = int(llvm_version.split(".")[0])
    target_system_name = {
        "darwin-x86_64": "x86_64-apple-macosx",
        "darwin-aarch64": "aarch64-apple-macosx",
        "linux-aarch64": "aarch64-unknown-linux-gnu",
        "linux-armv7": "armv7-unknown-linux-gnueabihf",
        "linux-x86_64": "x86_64-unknown-linux-gnu",
        "linux-riscv64": "riscv64-unknown-linux-gnu",
        "none-riscv32": "riscv32-unknown-none-elf",
        "none-riscv64": "riscv64-unknown-none-elf",
        "none-x86_64": "x86_64-unknown-none",
        "wasm32": "wasm32-unknown-unknown",
        "wasm64": "wasm64-unknown-unknown",
        "wasip1-wasm32": "wasm32-wasip1",
        "wasip1-wasm64": "wasm64-wasip1",
    }[target_pair]

    target_toolchain_root = toolchain_info.toolchain_root
    if target_pair in toolchain_info.target_toolchain_roots_dict:
        target_toolchain_root = toolchain_info.target_toolchain_roots_dict[target_pair]
    elif "" in toolchain_info.target_toolchain_roots_dict:
        target_toolchain_root = toolchain_info.target_toolchain_roots_dict[""]
    target_toolchain_path_prefix = toolchain_info.toolchain_path_prefix
    if target_pair in toolchain_info.target_toolchain_path_prefixes_dict:
        target_toolchain_path_prefix = toolchain_info.target_toolchain_path_prefixes_dict[target_pair]
    elif "" in toolchain_info.target_toolchain_roots_dict:
        target_toolchain_path_prefix = toolchain_info.target_toolchain_path_prefixes_dict[""]

    target_toolchain_include_path_prefix = target_toolchain_path_prefix
    if not use_absolute_paths_llvm:
        target_toolchain_include_path_prefix = "%workspace%/" + target_toolchain_include_path_prefix

    # C++ built-in include directories:
    resource_dir_version = llvm_version if major_llvm_version < 16 else major_llvm_version
    cxx_builtin_include_directories = [
        paths.join(target_toolchain_include_path_prefix, "include/c++/v1"),
        paths.join(target_toolchain_include_path_prefix, "lib/clang", str(resource_dir_version), "include"),
        # Sanitizer ignorelists (e.g. msan_ignorelist.txt) that Clang auto-loads
        # from the resource directory when a sanitizer is enabled; declared here
        # so Bazel's include validation accepts them as builtin toolchain files.
        paths.join(target_toolchain_include_path_prefix, "lib/clang", str(resource_dir_version), "share"),
        # Note(zbarsky): We could avoid this path if we renamed `include/{target_system_name}/c++/v1/__config_site` to `include/c++/v1/__config_site` in the LLVM repo.
        # However, that would preclude sharing it across multiple toolchain definitions.
        paths.join(target_toolchain_include_path_prefix, "include", target_system_name, "c++/v1"),
        # MSan-instrumented libc++ headers (present only when the distribution
        # was configured with `libcxx_url`). msan builds compile against these
        # via -cxx-isystem (see msan_cpp_system_includes in
        # cc_toolchain_config.bzl), so they must be declared builtin includes
        # for both Bazel's include validation and the generated system module
        # map. Without this, `layering_check` fails for libraries (e.g. abseil)
        # that include standard headers under msan. Non-existent when no msan
        # overlay is configured; the module map generator filters absent dirs.
        paths.join(target_toolchain_include_path_prefix, "libcxx-msan/include/c++/v1"),
        paths.join(target_toolchain_include_path_prefix, "libcxx-msan/include", target_system_name, "c++/v1"),
    ]

    # TODO(zbarsky): Not sure if these lib64 paths are actually needed for system toolchains?
    if use_absolute_paths_llvm:
        cxx_builtin_include_directories.extend([
            paths.join(target_toolchain_include_path_prefix, "lib64/clang", str(llvm_version), "include"),
            paths.join(target_toolchain_include_path_prefix, "lib64/clang", str(major_llvm_version), "include"),
        ])

    stdlib = _dict_value(toolchain_info.stdlib_dict, target_pair, "builtin-libc++")
    add_cxx_builtin_include_dirs_before_sysroot = target_os == "linux" and stdlib in ["stdc++", "dynamic-stdc++"]
    sysroot_prefix = ""
    if sysroot_path:
        sysroot_prefix = "%sysroot%"
    if target_os == "linux":
        if add_cxx_builtin_include_dirs_before_sysroot:
            cxx_builtin_include_directories.extend(toolchain_info.additional_include_dirs_dict.get(target_pair, []))

            # Add GCC C++ headers from sysroot when using libstdc++.
            # These paths are needed because clang doesn't automatically add them
            # to the include search path when cross-compiling with a sysroot.
            # See https://github.com/bazel-contrib/toolchains_llvm/issues/533
            if sysroot_path:
                # Common GCC C++ header locations in modern distros (Debian/Ubuntu)
                # Pattern: /usr/include/c++/<version> and /usr/include/<triple>/c++/<version>
                gcc_cxx_include_dirs = _detect_gcc_cxx_headers(rctx, sysroot_path, target_system_name)
                for dir in gcc_cxx_include_dirs:
                    cxx_builtin_include_directories.append(_join(sysroot_prefix, dir))

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
    elif target_os == "none" or target_os == "wasip1":
        if sysroot_prefix:
            cxx_builtin_include_directories.extend([
                _join(sysroot_prefix, "/include"),
            ])
    else:
        fail("Unreachable")

    if not add_cxx_builtin_include_dirs_before_sysroot:
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
    target_toolchain_path_prefix = "{target_toolchain_path_prefix}",
    tools_path_prefix = "{tools_path_prefix}",
    wrapper_bin_prefix = "{wrapper_bin_prefix}",
    redacted_dates_path = "{redacted_dates_path}",
    compiler_configuration = {{
      "sysroot_path": "{sysroot_path}",
      "stdlib": "{stdlib}",
      "multiarch": "{multiarch_override}",
      "cxx_include_layout": "{cxx_include_layout}",
      "cxx_standard": "{cxx_standard}",
      "compile_flags": {compile_flags},
      "conly_flags": {conly_flags},
      "cxx_flags": {cxx_flags},
      "link_flags": {link_flags},
      "archive_flags": {archive_flags},
      "link_libs": {link_libs},
      "fastbuild_compile_flags": {fastbuild_compile_flags},
      "opt_compile_flags": {opt_compile_flags},
      "opt_link_flags": {opt_link_flags},
      "dbg_compile_flags": {dbg_compile_flags},
      "coverage_compile_flags": {coverage_compile_flags},
      "coverage_link_flags": {coverage_link_flags},
      "unfiltered_compile_flags": {unfiltered_compile_flags},
      "extra_compile_flags": {extra_compile_flags},
      "extra_cxx_flags": {extra_cxx_flags},
      "extra_link_flags": {extra_link_flags},
      "extra_archive_flags": {extra_archive_flags},
      "extra_link_libs": {extra_link_libs},
      "extra_opt_compile_flags": {extra_opt_compile_flags},
      "extra_opt_link_flags": {extra_opt_link_flags},
      "extra_dbg_compile_flags": {extra_dbg_compile_flags},
      "extra_coverage_compile_flags": {extra_coverage_compile_flags},
      "extra_coverage_link_flags": {extra_coverage_link_flags},
      "extra_unfiltered_compile_flags": {extra_unfiltered_compile_flags},
    }},
    extra_known_features = {extra_known_features},
    extra_enabled_features = {extra_enabled_features},
    cxx_builtin_include_directories = {cxx_builtin_include_directories},
    llvm_version = "{llvm_version}",
)

toolchain(
    name = "cc-toolchain-{suffix}",
    exec_compatible_with = [
        "@platforms//cpu:{exec_arch}",
        "@platforms//os:{exec_os_bzl}",
    ] + {extra_exec_compatible_with_specific} + {extra_exec_compatible_with_all_targets},
    target_compatible_with = [
        "@platforms//cpu:{target_arch}",
        "@platforms//os:{target_os_bzl}",
    ] + {extra_target_compatible_with_specific} + {extra_target_compatible_with_all_targets},
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
    name = "cxx_builtin_include_files-{suffix}",
    srcs = [],
)

filegroup(
    name = "compiler-components-{suffix}",
    srcs = [
        ":sysroot-components-{suffix}",
        "redacted_dates.h",
        {extra_compiler_files}
    ],
)

filegroup(
    name = "linker-components-{suffix}",
    srcs = [
        ":sysroot-components-{suffix}",
        {extra_linker_files}
    ],
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
    name = "cxx_builtin_include_files-{suffix}",
    srcs = [
        "{target_toolchain_root}:{cxx_builtin_include_label}",
        {extra_compiler_files}
    ],
)

filegroup(
    name = "compiler-components-{suffix}",
    srcs = [
        ":cxx_builtin_include_files-{suffix}",
        ":sysroot-components-{suffix}",
        "{llvm_dist_label_prefix}extra_config_site",
        "{toolchain_root}:clang",
        "redacted_dates.h",
        {extra_compiler_files}
    ],
)

filegroup(
    name = "linker-components-{suffix}",
    srcs = [
        ":sysroot-components-{suffix}",
        "{toolchain_root}:clang",
        "{toolchain_root}:ld",
        "{toolchain_root}:ar",
        "{target_toolchain_root}:{lib_label}",
        {extra_linker_files}
    ],
)

filegroup(
    name = "all-components-{suffix}",
    srcs = [
        "{toolchain_root}:bin",
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
system_module_map(
    name = "module-{suffix}",
    cxx_builtin_include_files = ":cxx_builtin_include_files-{suffix}",
    cxx_builtin_include_directories = {cxx_builtin_include_directories},
    extra_textual_headers = "redacted_dates.h",
    sysroot_files = ":sysroot-components-{suffix}",
    sysroot_path = "{sysroot_path}",
)

filegroup(name = "runtime-libs-empty-{suffix}", srcs = [])

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
    supports_header_parsing = True,{runtime_lib_attrs}
)
"""

    # Filter out non-existing directories with absolute paths as they
    # result in a -Wincomplete-umbrella warning when mentioned in the
    # system module map. Note that this filtering is skipped for remote
    # execution because it is not possible to check directory existence.
    filtered_cxx_builtin_include_directories = cxx_builtin_include_directories if _is_remote(rctx, exec_os, exec_arch) else [
        dir
        for dir in cxx_builtin_include_directories
        if _is_hermetic_or_exists(rctx, dir, sysroot_path)
    ]

    # On macOS the sanitizer runtimes are dynamic-only and referenced as
    # `@rpath/libclang_rt.<san>_osx_dynamic.dylib`, so the dylib must travel
    # with sanitized binaries. Expose the matching runtime through
    # `dynamic_runtime_lib`: Bazel links it via the solib directory (with an
    # `@loader_path` rpath) and ships it in the binary's runfiles. Bazel only
    # consults these attributes when the `static_link_cpp_runtimes` feature is
    # enabled, which cc_toolchain_config.bzl arranges whenever a sanitizer
    # feature is on. Scoped to the hermetic toolchain; the host toolchain's
    # runtime is found at its absolute location. The computed text is passed as
    # a format argument (not inlined in the template) so its select() braces
    # are not re-interpreted by the outer format().
    runtime_lib_attrs = ""
    if target_os == "darwin" and not use_absolute_paths_llvm:
        runtime_lib_attrs = """
    static_runtime_lib = ":runtime-libs-empty-{suffix}",
    dynamic_runtime_lib = select({{
        "{use_asan}": "{root}:libclang_rt-asan-darwin",
        "{use_ubsan}": "{root}:libclang_rt-ubsan-darwin",
        "{use_tsan}": "{root}:libclang_rt-tsan-darwin",
        "//conditions:default": ":runtime-libs-empty-{suffix}",
    }}),""".format(
            suffix = suffix,
            root = target_toolchain_root,
            use_asan = str(Label("//toolchain/config:use_asan")),
            use_ubsan = str(Label("//toolchain/config:use_ubsan")),
            use_tsan = str(Label("//toolchain/config:use_tsan")),
        )

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
        toolchain_root = toolchain_info.toolchain_root,
        target_toolchain_root = target_toolchain_root,
        target_toolchain_path_prefix = target_toolchain_path_prefix,
        tools_path_prefix = toolchain_info.tools_path_prefix,
        wrapper_bin_prefix = toolchain_info.wrapper_bin_prefix,
        redacted_dates_path = "external/{}/redacted_dates.h".format(rctx.name),
        sysroot_label_str = sysroot_label_str,
        sysroot_path = sysroot_path,
        stdlib = stdlib,
        multiarch_override = toolchain_info.multiarch_dict.get(target_pair, ""),
        cxx_include_layout = toolchain_info.cxx_include_layout_dict.get(target_pair, ""),
        cxx_standard = _dict_value(toolchain_info.cxx_standard_dict, target_pair, "c++17"),
        compile_flags = _list_to_string(_dict_value(toolchain_info.compile_flags_dict, target_pair)),
        conly_flags = _list_to_string(toolchain_info.conly_flags_dict.get(target_pair, [])),
        cxx_flags = _list_to_string(_dict_value(toolchain_info.cxx_flags_dict, target_pair)),
        link_flags = _list_to_string(_dict_value(toolchain_info.link_flags_dict, target_pair)),
        archive_flags = _list_to_string(_dict_value(toolchain_info.archive_flags_dict, target_pair)),
        link_libs = _list_to_string(_dict_value(toolchain_info.link_libs_dict, target_pair)),
        fastbuild_compile_flags = _list_to_string(_dict_value(toolchain_info.fastbuild_compile_flags_dict, target_pair)),
        opt_compile_flags = _list_to_string(_dict_value(toolchain_info.opt_compile_flags_dict, target_pair)),
        opt_link_flags = _list_to_string(_dict_value(toolchain_info.opt_link_flags_dict, target_pair)),
        dbg_compile_flags = _list_to_string(_dict_value(toolchain_info.dbg_compile_flags_dict, target_pair)),
        coverage_compile_flags = _list_to_string(_dict_value(toolchain_info.coverage_compile_flags_dict, target_pair)),
        coverage_link_flags = _list_to_string(_dict_value(toolchain_info.coverage_link_flags_dict, target_pair)),
        unfiltered_compile_flags = _list_to_string(_dict_value(toolchain_info.unfiltered_compile_flags_dict, target_pair)),
        extra_compile_flags = _list_to_string(_dict_value(toolchain_info.extra_compile_flags_dict, target_pair)),
        extra_cxx_flags = _list_to_string(_dict_value(toolchain_info.extra_cxx_flags_dict, target_pair)),
        extra_link_flags = _list_to_string(_dict_value(toolchain_info.extra_link_flags_dict, target_pair)),
        extra_archive_flags = _list_to_string(_dict_value(toolchain_info.extra_archive_flags_dict, target_pair)),
        extra_link_libs = _list_to_string(_dict_value(toolchain_info.extra_link_libs_dict, target_pair)),
        extra_opt_compile_flags = _list_to_string(_dict_value(toolchain_info.extra_opt_compile_flags_dict, target_pair)),
        extra_opt_link_flags = _list_to_string(_dict_value(toolchain_info.extra_opt_link_flags_dict, target_pair)),
        extra_dbg_compile_flags = _list_to_string(_dict_value(toolchain_info.extra_dbg_compile_flags_dict, target_pair)),
        extra_coverage_compile_flags = _list_to_string(_dict_value(toolchain_info.extra_coverage_compile_flags_dict, target_pair)),
        extra_coverage_link_flags = _list_to_string(_dict_value(toolchain_info.extra_coverage_link_flags_dict, target_pair)),
        extra_unfiltered_compile_flags = _list_to_string(_dict_value(toolchain_info.extra_unfiltered_compile_flags_dict, target_pair)),
        extra_known_features = _list_to_string(toolchain_info.extra_known_features),
        extra_enabled_features = _list_to_string(toolchain_info.extra_enabled_features),
        extra_files_str = extra_files_str,
        cxx_builtin_include_directories = _list_to_string(filtered_cxx_builtin_include_directories),
        cxx_builtin_include_label = "cxx_builtin_include" if bazel_features.rules.merkle_cache_v2 else "include",
        lib_label = "lib" if bazel_features.rules.merkle_cache_v2 else "lib_legacy",
        extra_compiler_files = ("\"%s\"," % _extra_compiler_label) if _extra_compiler_label else "",
        llvm_version = llvm_version,
        extra_linker_files = ("\"%s\"," % _extra_linker_label) if _extra_linker_label else "",
        extra_exec_compatible_with_specific = toolchain_info.extra_exec_compatible_with.get(target_pair, []),
        extra_target_compatible_with_specific = toolchain_info.extra_target_compatible_with.get(target_pair, []),
        extra_exec_compatible_with_all_targets = toolchain_info.extra_exec_compatible_with.get("", []),
        extra_target_compatible_with_all_targets = toolchain_info.extra_target_compatible_with.get("", []),
        runtime_lib_attrs = runtime_lib_attrs,
    )

def _is_remote(rctx, exec_os, exec_arch):
    return not (_os_from_rctx(rctx) == exec_os and _arch_from_rctx(rctx) == exec_arch)

def _convenience_targets_str(rctx, use_absolute_paths, llvm_dist_rel_path, llvm_dist_label_prefix, exec_dl_ext):
    """Generate `cc_import`/`native_binary` aliases for the exec-platform LLVM distribution.

    These aliases (`clang`, `llvm-cov`, host `libc++`, ...) reference only the
    exec-platform LLVM distribution -- i.e. the binaries you `bazel run` and the
    libraries you might link host tools against. They are intentionally not
    parameterised over the target platform: when cross-compiling, the matching
    target-platform libraries live under the corresponding entry in
    `target_toolchain_roots` and should be referenced from there directly.
    """
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
            rctx.symlink(paths.join(llvm_dist_rel_path, filename), filename)

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
