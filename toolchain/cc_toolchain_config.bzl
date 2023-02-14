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

load(
    "@bazel_tools//tools/cpp:unix_cc_toolchain_config.bzl",
    unix_cc_toolchain_config = "cc_toolchain_config",
)
load(
    "//toolchain/internal:common.bzl",
    _check_os_arch_keys = "check_os_arch_keys",
    _host_tool_features = "host_tool_features",
    _host_tools = "host_tools",
    _os_arch_pair = "os_arch_pair",
)

# Bazel 4.* doesn't support nested skylark functions, so we cannot simplify
# _fmt_flags() by defining it as a nested function.
def _fmt_flags(flags, toolchain_path_prefix):
    return [f.format(toolchain_path_prefix = toolchain_path_prefix) for f in flags]

# Macro for calling cc_toolchain_config from @bazel_tools with setting the
# right paths and flags for the tools.
def cc_toolchain_config(
        name,
        host_arch,
        host_os,
        target_arch,
        target_os,
        toolchain_path_prefix,
        tools_path_prefix,
        wrapper_bin_prefix,
        compiler_configuration,
        llvm_version,
        host_tools_info = {}):
    host_os_arch_key = _os_arch_pair(host_os, host_arch)
    target_os_arch_key = _os_arch_pair(target_os, target_arch)
    _check_os_arch_keys([host_os_arch_key, target_os_arch_key])

    # A bunch of variables that get passed straight through to
    # `create_cc_toolchain_config_info`.
    # TODO: What do these values mean, and are they actually all correct?
    host_system_name = host_arch
    (
        toolchain_identifier,
        target_system_name,
        target_cpu,
        target_libc,
        compiler,
        abi_version,
        abi_libc_version,
    ) = {
        "darwin-x86_64": (
            "clang-x86_64-darwin",
            "x86_64-apple-macosx",
            "darwin",
            "macosx",
            "clang",
            "darwin_x86_64",
            "darwin_x86_64",
        ),
        "darwin-aarch64": (
            "clang-aarch64-darwin",
            "aarch64-apple-macosx",
            "darwin",
            "macosx",
            "clang",
            "darwin_aarch64",
            "darwin_aarch64",
        ),
        "linux-aarch64": (
            "clang-aarch64-linux",
            "aarch64-unknown-linux-gnu",
            "aarch64",
            "glibc_unknown",
            "clang",
            "clang",
            "glibc_unknown",
        ),
        "linux-x86_64": (
            "clang-x86_64-linux",
            "x86_64-unknown-linux-gnu",
            "k8",
            "glibc_unknown",
            "clang",
            "clang",
            "glibc_unknown",
        ),
    }[target_os_arch_key]

    # Unfiltered compiler flags; these are placed at the end of the command
    # line, so take precendence over any user supplied flags through --copts or
    # such.
    unfiltered_compile_flags = [
        # Do not resolve our symlinked resource prefixes to real paths.
        "-no-canonical-prefixes",
        # Reproducibility
        "-Wno-builtin-macro-redefined",
        "-D__DATE__=\"redacted\"",
        "-D__TIMESTAMP__=\"redacted\"",
        "-D__TIME__=\"redacted\"",
        "-fdebug-prefix-map={}=__bazel_toolchain_llvm_repo__/".format(toolchain_path_prefix),
    ]

    is_xcompile = not (host_os == target_os and host_arch == target_arch)

    # Default compiler flags:
    compile_flags = [
        "--target=" + target_system_name,
        # Security
        "-U_FORTIFY_SOURCE",  # https://github.com/google/sanitizers/issues/247
        "-fstack-protector",
        "-fno-omit-frame-pointer",
        # Diagnostics
        "-fcolor-diagnostics",
        "-Wall",
        "-Wthread-safety",
        "-Wself-assign",
    ]

    dbg_compile_flags = ["-g", "-fstandalone-debug"]

    opt_compile_flags = [
        "-g0",
        "-O2",
        "-D_FORTIFY_SOURCE=1",
        "-DNDEBUG",
        "-ffunction-sections",
        "-fdata-sections",
    ]

    link_flags = [
        "--target=" + target_system_name,
        "-lm",
        "-no-canonical-prefixes",
    ]

    # Similar to link_flags, but placed later in the command line such that
    # unused symbols are not stripped.
    link_libs = []

    # Linker flags:
    if host_os == "darwin" and not is_xcompile:
        # lld is experimental for Mach-O, so we use the native ld64 linker.
        # TODO: How do we cross-compile from Linux to Darwin?
        use_lld = False
        link_flags.extend([
            "-headerpad_max_install_names",
        ])
    else:
        # Note that for xcompiling from darwin to linux, the native ld64 is
        # not an option because it is not a cross-linker, so lld is the
        # only option.
        use_lld = True
        link_flags.extend([
            "-fuse-ld=lld",
            "-Wl,--build-id=md5",
            "-Wl,--hash-style=gnu",
            "-Wl,-z,relro,-z,now",
        ])

    # Flags related to C++ standard.
    # The linker has no way of knowing if there are C++ objects; so we
    # always link C++ libraries.
    cxx_standard = compiler_configuration["cxx_standard"]
    stdlib = compiler_configuration["stdlib"]
    if stdlib == "builtin-libc++" and is_xcompile:
        stdlib = "stdc++"
    if stdlib == "builtin-libc++":
        cxx_flags = [
            "-std=" + cxx_standard,
            "-stdlib=libc++",
        ]
        if use_lld:
            # For single-platform builds, we can statically link the bundled
            # libraries.
            link_flags.extend([
                "-l:libc++.a",
                "-l:libc++abi.a",
                "-l:libunwind.a",
                # Compiler runtime features.
                "-rtlib=compiler-rt",
                # To support libunwind.
                "-lpthread",
                "-ldl",
            ])
        else:
            # The only known mechanism to static link libraries in ld64 is to
            # not have the corresponding .dylib files in the library search
            # path. The link time sandbox does not include the .dylib files, so
            # anything we pick up from the toolchain should be statically
            # linked. However, several system libraries on macOS dynamically
            # link libc++ and libc++abi, so static linking them becomes a problem.
            # We need to ensure that they are dynamic linked from the system
            # sysroot and not static linked from the toolchain, so explicitly
            # have the sysroot directory on the search path and then add the
            # toolchain directory back after we are done.
            link_flags.extend([
                "-L{}/usr/lib".format(compiler_configuration["sysroot_path"]),
                "-lc++",
                "-lc++abi",
            ])

            # Let's provide the path to the toolchain library directory
            # explicitly as part of the search path to make it easy for a user
            # to pick up something. This also makes the behavior consistent with
            # targets when a user explicitly depends on something like
            # libomp.dylib, which adds this directory to the search path, and would
            # (unintentionally) lead to static linking of libraries from the
            # toolchain.
            link_flags.extend([
                "-L{}lib".format(toolchain_path_prefix),
            ])
    elif stdlib == "libc++":
        cxx_flags = [
            "-std=" + cxx_standard,
            "-stdlib=libc++",
        ]

        link_flags.extend([
            "-l:c++.a",
            "-l:c++abi.a",
        ])
    elif stdlib == "stdc++":
        cxx_flags = [
            "-std=" + cxx_standard,
            "-stdlib=libstdc++",
        ]

        link_flags.extend([
            "-l:libstdc++.a",
        ])
    elif stdlib == "none":
        cxx_flags = [
            "-nostdlib",
        ]

        link_flags.extend([
            "-nostdlib",
        ])
    else:
        fail("Unknown value passed for stdlib: {stdlib}".format(stdlib = stdlib))

    opt_link_flags = ["-Wl,--gc-sections"] if target_os == "linux" else []

    # Coverage flags:
    coverage_compile_flags = ["-fprofile-instr-generate", "-fcoverage-mapping"]
    coverage_link_flags = ["-fprofile-instr-generate"]

    ## NOTE: framework paths is missing here; unix_cc_toolchain_config
    ## doesn't seem to have a feature for this.

    # C++ built-in include directories:
    cxx_builtin_include_directories = []
    if toolchain_path_prefix.startswith("/"):
        cxx_builtin_include_directories.extend([
            toolchain_path_prefix + "include/c++/v1",
            toolchain_path_prefix + "include/{}/c++/v1".format(target_system_name),
            toolchain_path_prefix + "lib/clang/{}/include".format(llvm_version),
            toolchain_path_prefix + "lib/clang/{}/share".format(llvm_version),
            toolchain_path_prefix + "lib64/clang/{}/include".format(llvm_version),
        ])

    sysroot_path = compiler_configuration["sysroot_path"]
    sysroot_prefix = ""
    if sysroot_path:
        sysroot_prefix = "%sysroot%"
    if target_os == "linux":
        cxx_builtin_include_directories.extend([
            sysroot_prefix + "/include",
            sysroot_prefix + "/usr/include",
            sysroot_prefix + "/usr/local/include",
        ])
    elif target_os == "darwin":
        cxx_builtin_include_directories.extend([
            sysroot_prefix + "/usr/include",
            sysroot_prefix + "/System/Library/Frameworks",
        ])
    else:
        fail("Unreachable")

    cxx_builtin_include_directories.extend(compiler_configuration["additional_include_dirs"])

    ## NOTE: make variables are missing here; unix_cc_toolchain_config doesn't
    ## pass these to `create_cc_toolchain_config_info`.

    # Tool paths:
    # `llvm-strip` was introduced in V7 (https://reviews.llvm.org/D46407):
    llvm_version = llvm_version.split(".")
    llvm_major_ver = int(llvm_version[0]) if len(llvm_version) else 0
    strip_binary = (tools_path_prefix + "llvm-strip") if llvm_major_ver >= 7 else _host_tools.get_and_assert(host_tools_info, "strip")

    # TODO: The command line formed on darwin does not work with llvm-ar.
    ar_binary = tools_path_prefix + "llvm-ar"
    if host_os == "darwin":
        # Bazel uses arg files for longer commands; some old macOS `libtool`
        # versions do not support this.
        #
        # In these cases we want to use `libtool_wrapper.sh` which translates
        # the arg file back into command line arguments.
        if not _host_tools.tool_supports(host_tools_info, "libtool", features = [_host_tool_features.SUPPORTS_ARG_FILE]):
            ar_binary = wrapper_bin_prefix + "host_libtool_wrapper.sh"
        else:
            ar_binary = host_tools_info["libtool"]["path"]

    # The tool names come from [here](https://github.com/bazelbuild/bazel/blob/c7e58e6ce0a78fdaff2d716b4864a5ace8917626/src/main/java/com/google/devtools/build/lib/rules/cpp/CppConfiguration.java#L76-L90):
    # NOTE: Ensure these are listed in toolchain_tools in toolchain/internal/common.bzl.
    tool_paths = {
        "ar": ar_binary,
        "cpp": tools_path_prefix + "clang-cpp",
        "dwp": tools_path_prefix + "llvm-dwp",
        "gcc": wrapper_bin_prefix + "cc_wrapper.sh",
        "gcov": tools_path_prefix + "llvm-profdata",
        "ld": tools_path_prefix + "ld.lld" if use_lld else _host_tools.get_and_assert(host_tools_info, "ld"),
        "llvm-cov": tools_path_prefix + "llvm-cov",
        "llvm-profdata": tools_path_prefix + "llvm-profdata",
        "nm": tools_path_prefix + "llvm-nm",
        "objcopy": tools_path_prefix + "llvm-objcopy",
        "objdump": tools_path_prefix + "llvm-objdump",
        "strip": strip_binary,
    }

    # Start-end group linker support:
    # This was added to `lld` in this patch: http://reviews.llvm.org/D18814
    #
    # The oldest version of LLVM that we support is 6.0.0 which was released
    # after the above patch was merged, so we just set this to `True` when
    # `lld` is being used as the linker.
    supports_start_end_lib = use_lld

    # Replace flags with any user-provided overrides.
    if compiler_configuration["compile_flags"] != None:
        compile_flags = _fmt_flags(compiler_configuration["compile_flags"], toolchain_path_prefix)
    if compiler_configuration["cxx_flags"] != None:
        cxx_flags = _fmt_flags(compiler_configuration["cxx_flags"], toolchain_path_prefix)
    if compiler_configuration["link_flags"] != None:
        link_flags = _fmt_flags(compiler_configuration["link_flags"], toolchain_path_prefix)
    if compiler_configuration["link_libs"] != None:
        link_libs = _fmt_flags(compiler_configuration["link_libs"], toolchain_path_prefix)
    if compiler_configuration["opt_compile_flags"] != None:
        opt_compile_flags = _fmt_flags(compiler_configuration["opt_compile_flags"], toolchain_path_prefix)
    if compiler_configuration["opt_link_flags"] != None:
        opt_link_flags = _fmt_flags(compiler_configuration["opt_link_flags"], toolchain_path_prefix)
    if compiler_configuration["dbg_compile_flags"] != None:
        dbg_compile_flags = _fmt_flags(compiler_configuration["dbg_compile_flags"], toolchain_path_prefix)
    if compiler_configuration["coverage_compile_flags"] != None:
        coverage_compile_flags = _fmt_flags(compiler_configuration["coverage_compile_flags"], toolchain_path_prefix)
    if compiler_configuration["coverage_link_flags"] != None:
        coverage_link_flags = _fmt_flags(compiler_configuration["coverage_link_flags"], toolchain_path_prefix)
    if compiler_configuration["unfiltered_compile_flags"] != None:
        unfiltered_compile_flags = _fmt_flags(compiler_configuration["unfiltered_compile_flags"], toolchain_path_prefix)

    # Source: https://cs.opensource.google/bazel/bazel/+/master:tools/cpp/unix_cc_toolchain_config.bzl
    unix_cc_toolchain_config(
        name = name,
        cpu = target_cpu,
        compiler = compiler,
        toolchain_identifier = toolchain_identifier,
        host_system_name = host_system_name,
        target_system_name = target_system_name,
        target_libc = target_libc,
        abi_version = abi_version,
        abi_libc_version = abi_libc_version,
        cxx_builtin_include_directories = cxx_builtin_include_directories,
        tool_paths = tool_paths,
        compile_flags = compile_flags,
        dbg_compile_flags = dbg_compile_flags,
        opt_compile_flags = opt_compile_flags,
        cxx_flags = cxx_flags,
        link_flags = link_flags,
        link_libs = link_libs,
        opt_link_flags = opt_link_flags,
        unfiltered_compile_flags = unfiltered_compile_flags,
        coverage_compile_flags = coverage_compile_flags,
        coverage_link_flags = coverage_link_flags,
        supports_start_end_lib = supports_start_end_lib,
        builtin_sysroot = sysroot_path,
    )
