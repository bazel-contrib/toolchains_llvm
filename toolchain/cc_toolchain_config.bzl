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
    _os_arch_pair = "os_arch_pair",
)

# Bazel 4.* doesn't support nested starlark functions, so we cannot simplify
# _fmt_flags() by defining it as a nested function.
def _fmt_flags(flags, toolchain_path_prefix):
    return [f.format(toolchain_path_prefix = toolchain_path_prefix) for f in flags]

# Macro for calling cc_toolchain_config from @bazel_tools with setting the
# right paths and flags for the tools.
def cc_toolchain_config(
        name,
        exec_arch,
        exec_os,
        target_arch,
        target_os,
        target_system_name,
        toolchain_path_prefix,
        tools_path_prefix,
        wrapper_bin_prefix,
        compiler_configuration,
        cxx_builtin_include_directories,
        major_llvm_version):
    exec_os_arch_key = _os_arch_pair(exec_os, exec_arch)
    target_os_arch_key = _os_arch_pair(target_os, target_arch)
    _check_os_arch_keys([exec_os_arch_key, target_os_arch_key])

    # A bunch of variables that get passed straight through to
    # `create_cc_toolchain_config_info`.
    # TODO: What do these values mean, and are they actually all correct?
    (
        toolchain_identifier,
        target_cpu,
        target_libc,
        compiler,
        abi_version,
        abi_libc_version,
    ) = {
        "darwin-x86_64": (
            "clang-x86_64-darwin",
            "darwin",
            "macosx",
            "clang",
            "darwin_x86_64",
            "darwin_x86_64",
        ),
        "darwin-aarch64": (
            "clang-aarch64-darwin",
            "darwin",
            "macosx",
            "clang",
            "darwin_aarch64",
            "darwin_aarch64",
        ),
        "linux-aarch64": (
            "clang-aarch64-linux",
            "aarch64",
            "glibc_unknown",
            "clang",
            "clang",
            "glibc_unknown",
        ),
        "linux-x86_64": (
            "clang-x86_64-linux",
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

    is_xcompile = not (exec_os == target_os and exec_arch == target_arch)

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
        "-fuse-ld=lld",
    ]

    if exec_os == "darwin":
        # These will get expanded by osx_cc_wrapper's `sanitize_option`
        link_flags.append("--ld-path=ld.lld" if is_xcompile else "--ld-path=ld64.lld")

    # Similar to link_flags, but placed later in the command line such that
    # unused symbols are not stripped.
    link_libs = []
    libunwind_link_flags = []
    compiler_rt_link_flags = []

    is_darwin_exec_and_target = exec_os == "darwin" and not is_xcompile

    # Linker and archive flags
    if is_darwin_exec_and_target:
        link_flags.extend([
            "-headerpad_max_install_names",
            "-fobjc-link-runtime",
        ])

        # Use the bundled libtool (llvm-libtool-darwin).
        use_libtool = True

        # Pre-installed libtool on macOS has -static as default, but llvm-libtool-darwin needs it
        # explicitly. cc_common.create_link_variables does not automatically add this either if
        # output_file arg to it is None.
        archive_flags = ["-static"]
    else:
        link_flags.extend([
            "-Wl,--build-id=md5",
            "-Wl,--hash-style=gnu",
            "-Wl,-z,relro,-z,now",
        ])
        use_libtool = False
        archive_flags = []

    # Flags related to C++ standard.
    # The linker has no way of knowing if there are C++ objects; so we
    # always link C++ libraries.
    cxx_standard = compiler_configuration["cxx_standard"]
    stdlib = compiler_configuration["stdlib"]
    sysroot_path = compiler_configuration["sysroot_path"]
    if stdlib == "builtin-libc++" and is_xcompile:
        stdlib = "stdc++"
    if stdlib == "builtin-libc++":
        cxx_flags = [
            "-std=" + cxx_standard,
            "-stdlib=libc++",
        ]
        if major_llvm_version >= 14:
            # With C++20, Clang defaults to using C++ rather than Clang modules,
            # which breaks Bazel's `use_module_maps` feature, which is used by
            # `layering_check`. Since Bazel doesn't support C++ modules yet, it
            # is safe to disable them globally until the toolchain shipped by
            # Bazel sets this flag on `use_module_maps`.
            # https://github.com/llvm/llvm-project/commit/0556138624edf48621dd49a463dbe12e7101f17d
            cxx_flags.append("-Xclang")
            cxx_flags.append("-fno-cxx-modules")
        if is_darwin_exec_and_target:
            # Several system libraries on macOS dynamically link libc++ and
            # libc++abi, so static linking them becomes a problem. We need to
            # ensure that they are dynamic linked from the system sysroot and
            # not static linked from the toolchain, so explicitly have the
            # sysroot directory on the search path and then add the toolchain
            # directory back after we are done.
            link_flags.extend([
                "-L{}/usr/lib".format(sysroot_path),
                "-lc++",
                "-lc++abi",
                "-Bdynamic",
                "-L{}lib".format(toolchain_path_prefix),
            ])
            libunwind_link_flags = [
                "-Bstatic",
                "-lunwind",
            ]
        else:
            # For single-platform builds, we can statically link the bundled
            # libraries.
            link_flags.extend([
                "-l:libc++.a",
                "-l:libc++abi.a",
            ])
            compiler_rt_link_flags = ["-rtlib=compiler-rt"]
            libunwind_link_flags = [
                "-l:libunwind.a",
                # To support libunwind.
                "-lpthread",
                "-ldl",
            ]
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

    ## NOTE: make variables are missing here; unix_cc_toolchain_config doesn't
    ## pass these to `create_cc_toolchain_config_info`.

    # The requirements here come from
    # https://cs.opensource.google/bazel/bazel/+/master:src/main/starlark/builtins_bzl/common/cc/cc_toolchain_provider_helper.bzl;l=75;drc=f0150efd1cca473640269caaf92b5a23c288089d
    # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CcModule.java;l=1257;drc=6743d76f9ecde726d592e88d8914b9db007b1c43
    # https://cs.opensource.google/bazel/bazel/+/refs/tags/7.0.0:tools/cpp/unix_cc_toolchain_config.bzl;l=192,201;drc=044a14cca2747aeff258fc71eaeb153c08cb34d5
    # NOTE: Ensure these are listed in toolchain_tools in toolchain/internal/common.bzl.
    tool_paths = {
        "ar": tools_path_prefix + ("llvm-ar" if not use_libtool else "libtool"),
        "cpp": tools_path_prefix + "clang-cpp",
        "dwp": tools_path_prefix + "llvm-dwp",
        "gcc": wrapper_bin_prefix + "cc_wrapper.sh",
        "gcov": tools_path_prefix + "llvm-profdata",
        "ld": tools_path_prefix + "ld.lld",
        "llvm-cov": tools_path_prefix + "llvm-cov",
        "llvm-profdata": tools_path_prefix + "llvm-profdata",
        "nm": tools_path_prefix + "llvm-nm",
        "objcopy": tools_path_prefix + "llvm-objcopy",
        "objdump": tools_path_prefix + "llvm-objdump",
        "strip": tools_path_prefix + "llvm-strip",
    }

    # Start-end group linker support:
    # This was added to `lld` in this patch: http://reviews.llvm.org/D18814
    #
    # The oldest version of LLVM that we support is 6.0.0 which was released
    # after the above patch was merged, so we just set this to `True`.
    supports_start_end_lib = True

    # Replace flags with any user-provided overrides.
    if compiler_configuration["compile_flags"] != None:
        compile_flags = _fmt_flags(compiler_configuration["compile_flags"], toolchain_path_prefix)
    if compiler_configuration["cxx_flags"] != None:
        cxx_flags = _fmt_flags(compiler_configuration["cxx_flags"], toolchain_path_prefix)
    if compiler_configuration["link_flags"] != None:
        link_flags = _fmt_flags(compiler_configuration["link_flags"], toolchain_path_prefix)
    if compiler_configuration["archive_flags"] != None:
        archive_flags = _fmt_flags(compiler_configuration["archive_flags"], toolchain_path_prefix)
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
        host_system_name = exec_arch,
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
        link_flags = link_flags + select({str(Label("@toolchains_llvm//toolchain/config:use_libunwind")): libunwind_link_flags, "//conditions:default": []}) +
                     select({str(Label("@toolchains_llvm//toolchain/config:use_compiler_rt")): compiler_rt_link_flags, "//conditions:default": []}),
        archive_flags = archive_flags,
        link_libs = link_libs,
        opt_link_flags = opt_link_flags,
        unfiltered_compile_flags = unfiltered_compile_flags,
        coverage_compile_flags = coverage_compile_flags,
        coverage_link_flags = coverage_link_flags,
        supports_start_end_lib = supports_start_end_lib,
        builtin_sysroot = sysroot_path,
    )
