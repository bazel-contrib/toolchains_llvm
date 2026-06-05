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

load("@helly25_bzl//bzl/paths:paths.bzl", "paths")

# buildifier: disable=bzl-visibility
load(
    "@rules_cc//cc/private/toolchain:unix_cc_toolchain_config.bzl",
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
        target_toolchain_path_prefix,
        tools_path_prefix,
        wrapper_bin_prefix,
        redacted_dates_path,
        compiler_configuration,
        cxx_builtin_include_directories,
        extra_known_features,
        extra_enabled_features,
        llvm_version):
    exec_os_arch_key = _os_arch_pair(exec_os, exec_arch)
    target_os_arch_key = _os_arch_pair(target_os, target_arch)
    _check_os_arch_keys([exec_os_arch_key, target_os_arch_key])

    # The `*_path_prefix` arguments are substituted into flag templates (e.g.
    # `"-L{}lib".format(prefix)`) and into user-supplied flag templates via
    # _fmt_flags, so they must be directory paths ending in '/'. Normalize them
    # here so callers need not be precise. (Pure path *values* are built with
    # paths.join(), which does not depend on this.)
    toolchain_path_prefix = paths.ensure_trailing_slash(toolchain_path_prefix)
    target_toolchain_path_prefix = paths.ensure_trailing_slash(target_toolchain_path_prefix)
    tools_path_prefix = paths.ensure_trailing_slash(tools_path_prefix)
    wrapper_bin_prefix = paths.ensure_trailing_slash(wrapper_bin_prefix)

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
        multiarch,
    ) = {
        "darwin-x86_64": (
            "clang-x86_64-darwin",
            "darwin",
            "macosx",
            "clang",
            "darwin_x86_64",
            "darwin_x86_64",
            None,
        ),
        "darwin-aarch64": (
            "clang-aarch64-darwin",
            "darwin",
            "macosx",
            "clang",
            "darwin_aarch64",
            "darwin_aarch64",
            None,
        ),
        "linux-aarch64": (
            "clang-aarch64-linux",
            "aarch64",
            "glibc_unknown",
            "clang",
            "clang",
            "glibc_unknown",
            "aarch64-linux-gnu",
        ),
        "linux-armv7": (
            "clang-armv7-linux",
            "armv7",
            "glibc_unknown",
            "clang",
            "clang",
            "glibc_unknown",
            "arm-linux-gnueabihf",
        ),
        "linux-riscv64": (
            "clang-riscv64-linux",
            "riscv64",
            "glibc_unknown",
            "clang",
            "clang",
            "glibc_unknown",
            "riscv64-linux-gnu",
        ),
        "linux-x86_64": (
            "clang-x86_64-linux",
            "k8",
            "glibc_unknown",
            "clang",
            "clang",
            "glibc_unknown",
            "x86_64-linux-gnu",
        ),
        "none-riscv32": (
            "clang-riscv32-none",
            "riscv32",
            "unknown",
            "clang",
            "unknown",
            "unknown",
            None,
        ),
        "none-x86_64": (
            "clang-x86_64-none",
            "k8",
            "unknown",
            "clang",
            "unknown",
            "unknown",
            None,
        ),
        "wasm32": (
            "clang-wasm32",
            "wasm32",
            "unknown",
            "clang",
            "unknown",
            "unknown",
            None,
        ),
        "wasm64": (
            "clang-wasm64",
            "wasm64",
            "unknown",
            "clang",
            "unknown",
            "unknown",
            None,
        ),
        "wasip1-wasm32": (
            "clang-wasm32",
            "wasm32",
            "unknown",
            "clang",
            "unknown",
            "unknown",
            None,
        ),
        "wasip1-wasm64": (
            "clang-wasm64",
            "wasm64",
            "unknown",
            "clang",
            "unknown",
            "unknown",
            None,
        ),
    }[target_os_arch_key]

    # Unfiltered compiler flags; these are placed at the end of the command
    # line, so take precendence over any user supplied flags through --copts or
    # such.
    unfiltered_compile_flags = [
        # Do not resolve our symlinked resource prefixes to real paths.
        "-no-canonical-prefixes",
        # Reproducibility: redact date macros via an -imacros header rather than
        # -D__DATE__="redacted" on the command line, whose quotes are lost when
        # passed through sub-build flag strings.
        "-Wno-builtin-macro-redefined",
        "-imacros",
        redacted_dates_path,
    ]

    major_llvm_version = int(llvm_version.split(".")[0])

    resource_dir_version = llvm_version if major_llvm_version < 16 else major_llvm_version

    resource_dir = [
        "-resource-dir",
        paths.join(target_toolchain_path_prefix, "lib/clang", str(resource_dir_version)),
    ]

    # Clang's builtin headers (stddef.h, stdarg.h, intrinsics, ...). Searched
    # after the C++ standard library headers (see system_includes below).
    toolchain_builtin_include = paths.join(target_toolchain_path_prefix, "lib/clang", str(resource_dir_version), "include")

    target_flags = [
        "--target=" + target_system_name,
    ]

    # Default compiler flags:
    compile_flags = target_flags + [
        # Security
        "-U_FORTIFY_SOURCE",  # https://github.com/google/sanitizers/issues/247
        "-fstack-protector",
        "-fno-omit-frame-pointer",
        # Diagnostics
        "-fcolor-diagnostics",
        "-Wall",
        "-Wthread-safety",
        "-Wself-assign",
        "-B" + paths.ensure_trailing_slash(paths.join(toolchain_path_prefix, "bin")),
    ] + resource_dir

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

    link_flags = target_flags + [
        "-no-canonical-prefixes",
        "-fuse-ld=lld",
    ] + resource_dir

    # libc++ headers shipped with the toolchain, used when not building with
    # msan.
    #
    # These feed cpp_system_includes (emitted as -cxx-isystem) along with a
    # single -nostdinc++ at the end. -nostdinc++ disables Clang's automatic
    # detection of libc++ headers (which finds them adjacent to the clang
    # binary using an absolute path via getcwd()+argv[0]). Without this, our
    # explicit -cxx-isystem with a relative path and Clang's auto-detected
    # absolute path both point to the same directory but appear as separate
    # entries in the include search list. That breaks `#include_next` from
    # libc++ wrappers like <stdlib.h>: the "next" stdlib.h is found at the
    # duplicate path (empty due to its own header guard) instead of the C
    # library's stdlib.h, leaving types like `ldiv_t` and `size_t` undeclared.
    toolchain_cpp_system_includes = [
        paths.join(target_toolchain_path_prefix, "include/c++/v1"),
        paths.join(target_toolchain_path_prefix, "include", target_system_name, "c++/v1"),
    ]

    non_msan_link_flags = [
        "-L{}lib".format(target_toolchain_path_prefix),
        "-L{}lib/{}".format(target_toolchain_path_prefix, target_system_name),
    ]

    if exec_os == "darwin":
        # These will get expanded by osx_cc_wrapper's `sanitize_option`
        link_flags.append("--ld-path=ld64.lld" if target_os == "darwin" else "--ld-path=ld.lld")

    stdlib = compiler_configuration["stdlib"]
    if stdlib != "none":
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
    archive_flags = ["-static"] if is_darwin_exec_and_target else []

    # Flags related to C++ standard.
    # The linker has no way of knowing if there are C++ objects; so we
    # always link C++ libraries.
    cxx_standard = compiler_configuration["cxx_standard"]
    conly_flags = compiler_configuration["conly_flags"]
    sysroot_path = compiler_configuration["sysroot_path"]

    # Follow the same convention as the `*_path_prefix` arguments: a non-empty
    # sysroot path is a directory path ending in '/' (the sysroot flag templates
    # below substitute it directly). Normalize it here so callers need not be
    # precise; leave None/empty untouched to preserve the "no sysroot" case.
    if sysroot_path:
        sysroot_path = paths.ensure_trailing_slash(sysroot_path)

    # Flags related to C++ standard.
    cxx_flags = [
        "-std=" + cxx_standard,
    ]

    # System include directories accumulated per-stdlib below and turned into
    # search-path flags at the very end. C++ standard library dirs go into
    # cpp_system_includes (emitted as -cxx-isystem, plus a single -nostdinc++);
    # C/compiler system dirs go into system_includes (emitted as -idirafter so
    # they are searched after the C++ headers, which Clang requires). nostdinc
    # additionally drops Clang's default C system include paths.
    cpp_system_includes = []
    system_includes = []
    nostdinc = False

    is_xcompile = not (exec_os == target_os and exec_arch == target_arch)

    # We only support getting libc++ from the toolchain for now. Is it worth
    # supporting libc++ from the sysroot? Or maybe just part of a LLVM distribution
    # that's built for the target?
    if not stdlib and is_xcompile:
        # buildifier: disable=print
        print("WARNING: Using libc++ for host architecture while cross compiling, this is " +
              "probably not what you want. Explicitly set standard_libraries to libc++ to silence.")

    # Darwin has a universal sysroot so the builtin can compile cross-arch.
    if stdlib == "builtin-libc++" and is_xcompile and not is_darwin_exec_and_target:
        stdlib = "stdc++"
    if stdlib == "builtin-libc++":
        cxx_flags.extend([
            "-stdlib=libc++",
        ])
        system_includes.append(toolchain_builtin_include)
        if is_darwin_exec_and_target:
            # On macOS, use the SDK's libc++ entirely (headers + linking).
            # Clang's driver would otherwise auto-include the toolchain's
            # bundled libc++ headers (the LLVM version we built), creating an
            # ABI mismatch with the SDK's libc++.tbd that gets picked up via
            # the sysroot. The -nostdinc++ emitted with cpp_system_includes
            # disables Clang's default libc++ header search; here we point at
            # the SDK's headers instead of the toolchain's.
            cpp_system_includes = [
                paths.join(sysroot_path, "usr/include/c++/v1"),
            ]

            # Several system libraries on macOS dynamically link libc++ and
            # libc++abi, so static linking them becomes a problem. We need to
            # ensure that they are dynamic linked from the system sysroot and
            # not static linked from the toolchain, so explicitly have the
            # sysroot directory on the search path.
            #
            # The toolchain lib directory is intentionally NOT added to the
            # search path here. In sandboxed execution, the toolchain's lib/
            # directory is empty (only declared outputs are present), so the
            # previous -L flag was a harmless no-op. However, with
            # --spawn_strategy=local, the full toolchain lib/ directory is
            # visible to the linker, and ld64 discovers dylibs like
            # libunwind.1.dylib via the -L search path. These get baked into
            # the binary as LC_LOAD_DYLIB entries with @rpath install names
            # that fail at runtime because the toolchain directory is not in
            # the binary's @rpath search path.
            #
            # libunwind_link_flags is left empty on macOS because libunwind
            # is unconditionally provided by libSystem.B.dylib (clang always
            # passes -lSystem via Darwin.cpp). The toolchain's libunwind is
            # redundant and its dylib causes the runtime failure described
            # above, so the libunwind config flag has no effect on macOS.
            link_flags.extend([
                "-L{}usr/lib".format(sysroot_path),
                "-lc++",
                "-lc++abi",
                "-Bdynamic",
            ])
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
        cxx_flags.extend([
            "-stdlib=libc++",
        ])

        link_libs.extend([
            "-l:libc++.a",
            "-l:libc++abi.a",
        ])
    elif stdlib == "dynamic-stdc++":
        cxx_flags.extend([
            "-std=" + cxx_standard,
            "-stdlib=libstdc++",
        ])

        link_libs.extend([
            "-lstdc++",
        ])
    elif stdlib.startswith("stdc++"):
        # We use libgcc when using libstdc++ from a sysroot. Most libstdc++
        # builds link to libgcc, which means we need to use libgcc's exception
        # handling implementation, not the separate one in compiler-rt.
        # Unfortunately, clang sometimes emits code incompatible with libgcc,
        # see <https://bugs.llvm.org/show_bug.cgi?id=27455> and
        # <https://lists.llvm.org/pipermail/cfe-dev/2016-April/048466.html> for
        # example. This seems to be a commonly-used configuration with clang
        # though, so it's probably good enough for most people.
        link_flags.extend([
            "-L{}lib".format(target_toolchain_path_prefix),
            "-L{}lib/{}".format(target_toolchain_path_prefix, target_system_name),
        ])

        link_libs.extend([
            "-l:libstdc++.a",
        ])
        if stdlib == "stdc++":
            cxx_flags.extend([
                "-stdlib=libstdc++",
            ])
        elif stdlib.startswith("stdc++-"):
            if sysroot_path == None:
                fail("Need a sysroot to link against stdc++")

            # -stdlib does nothing when using -nostdinc besides produce a warning
            # that it's unused, so don't use it here.
            libstdcxx_version = stdlib[len("stdc++-"):]

            cpp_system_includes = [
                paths.join(sysroot_path, "usr/include/c++", libstdcxx_version),
                paths.join(sysroot_path, "usr/include", multiarch, "c++", libstdcxx_version),
                paths.join(sysroot_path, "usr/include/c++", libstdcxx_version, "backward"),
            ]

            # Clang really wants C system header includes after C++ ones, so
            # drop the default C system paths and add the toolchain's builtin
            # headers via system_includes (-idirafter).
            nostdinc = True
            system_includes.append(toolchain_builtin_include)

            link_flags.extend([
                "-L{}usr/lib/gcc/{}/{}".format(sysroot_path, multiarch, libstdcxx_version),
            ])
        else:
            fail("Invalid stdlib: " + stdlib)
    elif stdlib == "libc":
        pass
    elif stdlib == "none":
        cxx_flags = [
            "-nostdlib",
        ]
        link_flags.extend([
            "-nostdlib",
        ])
    else:
        fail("Unknown value passed for stdlib: {stdlib}".format(stdlib = stdlib))

    # On macOS the libc++ headers come from the SDK (see above), not the
    # toolchain, so do not add the toolchain's libc++ include paths.
    use_toolchain_libcxx_paths = stdlib in ["builtin-libc++", "libc++"] and target_os != "darwin"
    if use_toolchain_libcxx_paths:
        cpp_system_includes = toolchain_cpp_system_includes

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

    # The requirements here come from
    # https://cs.opensource.google/bazel/bazel/+/master:src/main/starlark/builtins_bzl/common/cc/cc_toolchain_provider_helper.bzl;l=75;drc=f0150efd1cca473640269caaf92b5a23c288089d
    # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/cpp/CcModule.java;l=1257;drc=6743d76f9ecde726d592e88d8914b9db007b1c43
    # https://cs.opensource.google/bazel/bazel/+/refs/tags/7.0.0:tools/cpp/unix_cc_toolchain_config.bzl;l=192,201;drc=044a14cca2747aeff258fc71eaeb153c08cb34d5
    # https://github.com/bazelbuild/rules_cc/blob/fe41fc4ea219c9d3680ee536bba6681f3baf838e/cc/private/toolchain/unix_cc_toolchain_config.bzl#L1887
    # NOTE: Ensure these are listed in toolchain_tools in toolchain/internal/common.bzl.
    tool_paths = {
        "ar": paths.join(tools_path_prefix, "llvm-ar" if not use_libtool else "libtool"),
        "cpp": paths.join(tools_path_prefix, "clang-cpp"),
        "dwp": paths.join(tools_path_prefix, "llvm-dwp"),
        "gcc": paths.join(wrapper_bin_prefix, "cc_wrapper.sh"),
        "gcov": paths.join(tools_path_prefix, "llvm-profdata"),
        "ld": paths.join(tools_path_prefix, "ld.lld"),
        "llvm-cov": paths.join(tools_path_prefix, "llvm-cov"),
        "llvm-profdata": paths.join(tools_path_prefix, "llvm-profdata"),
        "nm": paths.join(tools_path_prefix, "llvm-nm"),
        "objcopy": paths.join(tools_path_prefix, "llvm-objcopy"),
        "objdump": paths.join(tools_path_prefix, "llvm-objdump"),
        "strip": paths.join(tools_path_prefix, "llvm-strip"),
        "parse_headers": paths.join(wrapper_bin_prefix, "cc_wrapper.sh"),
    }

    # Start-end group linker support:
    # This was added to `lld` in this patch: http://reviews.llvm.org/D18814
    #
    # The oldest version of LLVM that we support is 6.0.0 which was released
    # after the above patch was merged, so we just set this to `True`.
    supports_start_end_lib = True

    # Replace flags with any user-provided overrides.
    if compiler_configuration["compile_flags"] != None:
        compile_flags.extend(_fmt_flags(compiler_configuration["compile_flags"], toolchain_path_prefix))
    if compiler_configuration["cxx_flags"] != None:
        cxx_flags.extend(_fmt_flags(compiler_configuration["cxx_flags"], toolchain_path_prefix))
    if compiler_configuration["link_flags"] != None:
        link_flags.extend(_fmt_flags(compiler_configuration["link_flags"], toolchain_path_prefix))
    if compiler_configuration["archive_flags"] != None:
        archive_flags.extend(_fmt_flags(compiler_configuration["archive_flags"], toolchain_path_prefix))
    if compiler_configuration["link_libs"] != None:
        link_libs.extend(_fmt_flags(compiler_configuration["link_libs"], toolchain_path_prefix))
    if compiler_configuration["opt_compile_flags"] != None:
        opt_compile_flags.extend(_fmt_flags(compiler_configuration["opt_compile_flags"], toolchain_path_prefix))
    if compiler_configuration["opt_link_flags"] != None:
        opt_link_flags.extend(_fmt_flags(compiler_configuration["opt_link_flags"], toolchain_path_prefix))
    if compiler_configuration["dbg_compile_flags"] != None:
        dbg_compile_flags.extend(_fmt_flags(compiler_configuration["dbg_compile_flags"], toolchain_path_prefix))
    if compiler_configuration["fastbuild_compile_flags"] != None:
        fastbuild_compile_flags.extend(_fmt_flags(compiler_configuration["fastbuild_compile_flags"], toolchain_path_prefix))
    if compiler_configuration["coverage_compile_flags"] != None:
        coverage_compile_flags.extend(_fmt_flags(compiler_configuration["coverage_compile_flags"], toolchain_path_prefix))
    if compiler_configuration["coverage_link_flags"] != None:
        coverage_link_flags.extend(_fmt_flags(compiler_configuration["coverage_link_flags"], toolchain_path_prefix))
    if compiler_configuration["unfiltered_compile_flags"] != None:
        unfiltered_compile_flags.extend(_fmt_flags(compiler_configuration["unfiltered_compile_flags"], toolchain_path_prefix))

    # Turn the accumulated include directories into search-path flags. The C++
    # standard library dirs are searched first (-cxx-isystem) and the C/system
    # dirs after them (-idirafter), which is what Clang expects.
    # TODO(AustinSchuh): Add msan support and make this conditional.
    if cpp_system_includes:
        cxx_flags = ["-nostdinc++"] + [
            flag
            for include in cpp_system_includes
            for flag in ("-cxx-isystem", include)
        ] + cxx_flags
    if nostdinc:
        compile_flags.append("-nostdinc")
    compile_flags += [
        flag
        for include in system_includes
        for flag in ("-idirafter", include)
    ]

    # Add the sysroot flags here, as we want to check these last
    if sysroot_path != None:
        external_include_paths = [
            paths.join(sysroot_path, "usr/local/include"),
        ]
        if multiarch != None:
            external_include_paths.extend([
                paths.join(sysroot_path, "usr", multiarch, "include"),
                paths.join(sysroot_path, "usr/include", multiarch),
            ])

        external_include_paths.extend([
            paths.join(sysroot_path, "usr/include"),
            paths.join(sysroot_path, "include"),
        ])

        if nostdinc:
            # With -nostdinc Clang no longer derives the sysroot's C system
            # include paths from --sysroot, so add them explicitly. Emit them
            # as -idirafter so they are searched after the compiler builtin
            # headers (system_includes, above) and the C++ standard library
            # headers (cpp_system_includes, via -cxx-isystem). Clang orders the
            # -cxx-isystem (CXXSystem) group after the -isystem (System) group,
            # so the C library headers must land in the later -idirafter (After)
            # group for #include_next from libstdc++ wrappers like <cstdlib> to
            # resolve to them.
            compile_flags += [
                flag
                for p in external_include_paths
                for flag in ("-idirafter", p)
            ]

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
                     select({str(Label("@toolchains_llvm//toolchain/config:use_compiler_rt")): compiler_rt_link_flags, "//conditions:default": []}) +
                     (non_msan_link_flags if use_toolchain_libcxx_paths else []),
        archive_flags = archive_flags,
        link_libs = link_libs,
        opt_link_flags = opt_link_flags,
        unfiltered_compile_flags = unfiltered_compile_flags,
        coverage_compile_flags = coverage_compile_flags,
        coverage_link_flags = coverage_link_flags,
        supports_start_end_lib = supports_start_end_lib,
        builtin_sysroot = sysroot_path,
        extra_enabled_features = extra_enabled_features,
        extra_known_features = extra_known_features,
    )
