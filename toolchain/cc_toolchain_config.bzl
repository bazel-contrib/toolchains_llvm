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

# buildifier: disable=bzl-visibility
load(
    "@rules_cc//cc/private/toolchain:unix_cc_toolchain_config.bzl",
    unix_cc_toolchain_config = "cc_toolchain_config",
)
load(
    "@rules_cc//cc/private/toolchain:windows_cc_toolchain_config.bzl",
    windows_cc_toolchain_config = "cc_toolchain_config",
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

def _machine_arch(target_arch):
    if target_arch == "x86_64":
        return "X64"
    elif target_arch == "aarch64":
        return "ARM64"
    else:
        fail("Unsupported target architecture: {}".format(target_arch))

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
        "linux-armv7": (
            "clang-armv7-linux",
            "armv7",
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
        "none-riscv32": (
            "clang-riscv32-none",
            "riscv32",
            "unknown",
            "clang",
            "unknown",
            "unknown",
        ),
        "none-x86_64": (
            "clang-x86_64-none",
            "k8",
            "unknown",
            "clang",
            "unknown",
            "unknown",
        ),
        "wasm32": (
            "clang-wasm32",
            "wasm32",
            "unknown",
            "clang",
            "unknown",
            "unknown",
        ),
        "wasm64": (
            "clang-wasm64",
            "wasm64",
            "unknown",
            "clang",
            "unknown",
            "unknown",
        ),
        "wasip1-wasm32": (
            "clang-wasm32",
            "wasm32",
            "unknown",
            "clang",
            "unknown",
            "unknown",
        ),
        "wasip1-wasm64": (
            "clang-wasm64",
            "wasm64",
            "unknown",
            "clang",
            "unknown",
            "unknown",
        ),
        "windows-x86_64": (
            "clang-x86_64-windows",
            "x64_windows",
            "msvc",
            "clang-cl",
            "unknown",
            "unknown",
        ),
        "windows-aarch64": (
            "clang-aarch64-windows",
            "arm64_windows",
            "msvc",
            "clang-cl",
            "unknown",
            "unknown",
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
    ]

    sysroot_path = compiler_configuration["sysroot_path"]

    # Default compiler flags:
    compile_flags = [
        "--target=" + target_system_name,
        # Diagnostics
        "-fcolor-diagnostics",
    ]
    if compiler == "clang-cl":
        compile_flags.extend([
            "/Wall",
            "/MT",
            "/Brepro",
            "/DWIN32",
            "/D_WIN32",
            "/D_WINDOWS",
            "/clang:-fdebug-prefix-map={}=__bazel_toolchain_llvm_repo__/".format(toolchain_path_prefix),
            "/clang-I{}/Include".format(sysroot_path),
        ])
    else:
        compile_flags.extend([
            # Security
            "-U_FORTIFY_SOURCE",  # https://github.com/google/sanitizers/issues/247
            "-fstack-protector",
            "-fno-omit-frame-pointer",
            # Diagnostics
            "-Wall",
            "-Wthread-safety",
            "-Wself-assign",
        ])

    dbg_compile_flags = ["-g", "-fstandalone-debug"]

    fastbuild_compile_flags = []

    opt_compile_flags = [
        "-g0",
        "-O2",
        "-D_FORTIFY_SOURCE=1",
        "-DNDEBUG",
        "-ffunction-sections",
        "-fdata-sections",
    ]

    if compiler == "clang-cl":  # TODO: technically it should be a check if the linker is `lld-link` instead, but we don't declare such value
        link_flags = [
            # The --target flag is for some uninvestigated yet reason required for Cargo build script to work on Windows ARM, otherwise it fails with:
            #     ERROR: C:/temp/k7ozco62/external/rules_rust++crate+fleet_crates__windows_aarch64_msvc-0.52.6/BUILD.bazel:75:19:
            #        error while validating output tree artifact external/rules_rust++crate+fleet_crates__windows_aarch64_msvc-0.52.6/_bs.cargo_runfiles:
            #           C:\temp\k7ozco62\execroot\_main\bazel-out\arm64_windows-fastbuild\bin\external\rules_rust++crate+fleet_crates__windows_aarch64_msvc-0.52.6\_bs.cargo_runfiles\rules_rust++crate+fleet_crates__windows_aarch64_msvc-0.52.6
            #      ERROR: C:/temp/k7ozco62/external/rules_rust++crate+fleet_crates__windows_aarch64_msvc-0.52.6/BUILD.bazel:75:19: Running Cargo build script windows_aarch64_msvc failed: not all outputs were created or valid
            "--target=" + target_system_name,
            "/MACHINE:{}".format(_machine_arch(target_arch)),
        ]
    else:
        link_flags = [
            "--target=" + target_system_name,
            "-no-canonical-prefixes",
            "-fuse-ld=lld",
        ]

    if exec_os == "darwin":
        # These will get expanded by osx_cc_wrapper's `sanitize_option`
        link_flags.append("--ld-path=ld64.lld" if target_os == "darwin" else "--ld-path=ld.lld")

    stdlib = compiler_configuration["stdlib"]
    if stdlib != "none" and compiler != "clang-cl":  # TODO: technically it should be a check if the linker is `lld-link` instead, but we don't declare such value
        link_flags.extend([
            "-lm",
        ])

    # Similar to link_flags, but placed later in the command line such that
    # unused symbols are not stripped.
    link_libs = []
    libunwind_link_flags = []
    compiler_rt_link_flags = []

    is_darwin_exec_and_target = exec_os == "darwin" and target_os == "darwin"

    # Linker flags:
    if is_darwin_exec_and_target:
        link_flags.extend([
            "-headerpad_max_install_names",
            "-fobjc-link-runtime",
        ])

        # Use the bundled libtool (llvm-libtool-darwin).
        use_libtool = True
    elif target_arch in ["wasm32", "wasm64"]:
        # lld is invoked as wasm-ld for WebAssembly targets.
        use_libtool = False
    elif compiler == "clang-cl":
        link_flags.extend([
            "/LIBPATH:{}/Lib".format(sysroot_path),
        ])
        use_libtool = False
    else:
        link_flags.extend([
            "-Wl,--build-id=md5",
            "-Wl,--hash-style=gnu",
            "-Wl,-z,relro,-z,now",
        ])
        use_libtool = False

    # Pre-installed libtool on macOS has -static as default, but llvm-libtool-darwin needs it
    # explicitly. cc_common.create_link_variables does not automatically add this either if
    # output_file arg to it is None.
    if is_darwin_exec_and_target:
        archive_flags = ["-static"]
    elif compiler == "clang-cl" and target_os == "windows":
        archive_flags = ["/MACHINE:{}".format(_machine_arch(target_arch))]
    else:
        archive_flags = []

    # Flags related to C++ standard.
    # The linker has no way of knowing if there are C++ objects; so we
    # always link C++ libraries.
    cxx_standard = compiler_configuration["cxx_standard"]
    conly_flags = compiler_configuration["conly_flags"]

    is_xcompile = not (exec_os == target_os and exec_arch == target_arch)

    # Darwin has a universal sysroot so the builtin can compile cross-arch.
    if stdlib == "builtin-libc++" and is_xcompile and not is_darwin_exec_and_target:
        stdlib = "stdc++"
    if stdlib == "builtin-libc++":
        cxx_flags = [
            "-std=" + cxx_standard,
            "-stdlib=libc++",
        ]

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
        elif target_os == "windows":
            pass
        else:
            # For single-platform builds, we can statically link the bundled
            # libraries.
            link_libs.extend([
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

        link_libs.extend([
            "-l:libc++.a",
            "-l:libc++abi.a",
        ])
    elif stdlib == "dynamic-stdc++":
        cxx_flags = [
            "-std=" + cxx_standard,
            "-stdlib=libstdc++",
        ]

        link_flags.extend([
            "-lstdc++",
        ])
    elif stdlib == "stdc++":
        cxx_flags = [
            "-std=" + cxx_standard,
            "-stdlib=libstdc++",
        ]

        link_flags.extend([
            "-l:libstdc++.a",
        ])
    elif stdlib == "libc":
        cxx_flags = [
            "-std=" + cxx_standard,
        ]
    elif stdlib == "none":
        cxx_flags = [
            "-nostdlib",
        ]
        link_flags.extend([
            "-nostdlib",
        ])
    elif compiler == "clang-cl" and target_libc == "msvc":
        cxx_flags = [
            "/std:" + cxx_standard,
            "-fms-compatibility",
            "-fms-extensions",
        ]
    else:
        fail("Unknown value passed for stdlib: {stdlib}".format(stdlib = stdlib))

    if major_llvm_version >= 14:
        # With C++20, Clang defaults to using C++ rather than Clang modules,
        # which breaks Bazel's `use_module_maps` feature, which is used by
        # `layering_check`. Since Bazel doesn't support C++ modules yet, it
        # is safe to disable them globally until the toolchain shipped by
        # Bazel sets this flag on `use_module_maps`.
        # https://github.com/llvm/llvm-project/commit/0556138624edf48621dd49a463dbe12e7101f17d
        cxx_flags.append("-Xclang")
        cxx_flags.append("-fno-cxx-modules")
        cxx_flags.append("-Wno-module-import-in-extern-c")

    opt_link_flags = ["-Wl,--gc-sections"] if target_os == "linux" else []

    # Coverage flags:
    coverage_compile_flags = ["-fprofile-instr-generate", "-fcoverage-mapping"]
    coverage_link_flags = ["-fprofile-instr-generate"]

    ## NOTE: framework paths is missing here; unix_cc_toolchain_config
    ## doesn't seem to have a feature for this.

    ## NOTE: make variables are missing here; unix_cc_toolchain_config doesn't
    ## pass these to `create_cc_toolchain_config_info`.

    binary_ext = ""
    if exec_os == "windows":
        binary_ext = ".exe"

    # The requirements here come from
    # https://cs.opensource.google/bazel/bazel/+/master:src/main/starlark/builtins_bzl/common/cc/cc_toolchain_provider_helper.bzl;l=75;drc=f0150efd1cca473640269caaf92b5a23c288089d
    # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CcModule.java;l=1257;drc=6743d76f9ecde726d592e88d8914b9db007b1c43
    # https://cs.opensource.google/bazel/bazel/+/refs/tags/7.0.0:tools/cpp/unix_cc_toolchain_config.bzl;l=192,201;drc=044a14cca2747aeff258fc71eaeb153c08cb34d5
    # https://github.com/bazelbuild/rules_cc/blob/fe41fc4ea219c9d3680ee536bba6681f3baf838e/cc/private/toolchain/unix_cc_toolchain_config.bzl#L1887
    # NOTE: Ensure these are listed in toolchain_tools in toolchain/internal/common.bzl.
    tool_paths = {
        "ar": tools_path_prefix + ("llvm-ar" if not use_libtool else "libtool") + binary_ext,
        "cpp": tools_path_prefix + "clang-cpp" + binary_ext,
        "dwp": tools_path_prefix + "llvm-dwp" + binary_ext,
        "gcc": tools_path_prefix + "clang-cl" + binary_ext if target_os == "windows" else wrapper_bin_prefix + "cc_wrapper.sh",
        "gcov": tools_path_prefix + "llvm-profdata" + binary_ext,
        "ld": tools_path_prefix + "lld-link" + binary_ext if target_os == "windows" else tools_path_prefix + "ld.lld" + binary_ext,
        "llvm-lib": tools_path_prefix + "llvm-lib" + binary_ext,
        "llvm-cov": tools_path_prefix + "llvm-cov" + binary_ext,
        "llvm-profdata": tools_path_prefix + "llvm-profdata" + binary_ext,
        "nm": tools_path_prefix + "llvm-nm" + binary_ext,
        "objcopy": tools_path_prefix + "llvm-objcopy" + binary_ext,
        "objdump": tools_path_prefix + "llvm-objdump" + binary_ext,
        "strip": tools_path_prefix + "llvm-strip" + binary_ext,
        "parse_headers": wrapper_bin_prefix + "cc_wrapper.sh",
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
    if compiler_configuration["fastbuild_compile_flags"] != None:
        fastbuild_compile_flags = _fmt_flags(compiler_configuration["fastbuild_compile_flags"], toolchain_path_prefix)
    if compiler_configuration["coverage_compile_flags"] != None:
        coverage_compile_flags = _fmt_flags(compiler_configuration["coverage_compile_flags"], toolchain_path_prefix)
    if compiler_configuration["coverage_link_flags"] != None:
        coverage_link_flags = _fmt_flags(compiler_configuration["coverage_link_flags"], toolchain_path_prefix)
    if compiler_configuration["unfiltered_compile_flags"] != None:
        unfiltered_compile_flags = _fmt_flags(compiler_configuration["unfiltered_compile_flags"], toolchain_path_prefix)

    if compiler_configuration["extra_compile_flags"] != None:
        compile_flags.extend(_fmt_flags(compiler_configuration["extra_compile_flags"], toolchain_path_prefix))
    if compiler_configuration["extra_cxx_flags"] != None:
        cxx_flags.extend(_fmt_flags(compiler_configuration["extra_cxx_flags"], toolchain_path_prefix))
    if compiler_configuration["extra_link_flags"] != None:
        link_flags.extend(_fmt_flags(compiler_configuration["extra_link_flags"], toolchain_path_prefix))
    if compiler_configuration["extra_archive_flags"] != None:
        archive_flags.extend(_fmt_flags(compiler_configuration["extra_archive_flags"], toolchain_path_prefix))
    if compiler_configuration["extra_link_libs"] != None:
        link_libs.extend(_fmt_flags(compiler_configuration["extra_link_libs"], toolchain_path_prefix))
    if compiler_configuration["extra_opt_compile_flags"] != None:
        opt_compile_flags.extend(_fmt_flags(compiler_configuration["extra_opt_compile_flags"], toolchain_path_prefix))
    if compiler_configuration["extra_opt_link_flags"] != None:
        opt_link_flags.extend(_fmt_flags(compiler_configuration["extra_opt_link_flags"], toolchain_path_prefix))
    if compiler_configuration["extra_dbg_compile_flags"] != None:
        dbg_compile_flags.extend(_fmt_flags(compiler_configuration["extra_dbg_compile_flags"], toolchain_path_prefix))
    if compiler_configuration["extra_coverage_compile_flags"] != None:
        coverage_compile_flags.extend(_fmt_flags(compiler_configuration["extra_coverage_compile_flags"], toolchain_path_prefix))
    if compiler_configuration["extra_coverage_link_flags"] != None:
        coverage_link_flags.extend(_fmt_flags(compiler_configuration["extra_coverage_link_flags"], toolchain_path_prefix))
    if compiler_configuration["extra_unfiltered_compile_flags"] != None:
        unfiltered_compile_flags.extend(_fmt_flags(compiler_configuration["extra_unfiltered_compile_flags"], toolchain_path_prefix))

    if target_os == "windows" and compiler == "clang-cl" and target_libc == "msvc":
        windows_cc_toolchain_config(
            name = name,
            cpu = target_cpu,
            compiler = compiler,
            toolchain_identifier = toolchain_identifier,
            host_system_name = exec_arch,
            target_system_name = target_system_name,
            target_libc = target_libc,
            abi_version = abi_version,
            abi_libc_version = abi_libc_version,
            msvc_env_include = ";".join([
                "{}/Include".format(sysroot_path),
            ]),
            # msvc_env_lib = ";".join([
            #     "{}/Lib".format(sysroot_path),
            # ]),
            msvc_cl_path = tool_paths["gcc"],
            msvc_link_path = tool_paths["ld"],
            msvc_lib_path = tool_paths["llvm-lib"],
            cxx_builtin_include_directories = cxx_builtin_include_directories,
            tool_paths = tool_paths,
            archiver_flags = archive_flags,
            default_link_flags = link_flags,
            default_compile_flags = compile_flags + unfiltered_compile_flags,
            dbg_mode_debug_flag = " ".join(dbg_compile_flags),
            fastbuild_mode_debug_flag = " ".join(fastbuild_compile_flags),
            supports_parse_showincludes = False,

            # The following attributes are not yet supported (we had no need for it):
            # msvc_env_tmp =
            # msvc_env_path =
            # msvc_ml_path =
            #
            # The following variables are not used on Windows toolchains:
            # - opt_compile_flags
            # - conly_flags
            # - cxx_flags
            # - link_libs
        )
    else:
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
            fastbuild_compile_flags = fastbuild_compile_flags,
            dbg_compile_flags = dbg_compile_flags,
            opt_compile_flags = opt_compile_flags,
            conly_flags = conly_flags,
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
