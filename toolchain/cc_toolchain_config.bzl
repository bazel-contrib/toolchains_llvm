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
load("@rules_cc//cc/toolchains:args.bzl", "cc_args")
load("@rules_cc//cc/toolchains:feature.bzl", "cc_feature")
load("@rules_cc//cc/toolchains:feature_constraint.bzl", "cc_feature_constraint")
load("@rules_cc//cc/toolchains:feature_set.bzl", "cc_feature_set")
load(
    "//toolchain/internal:common.bzl",
    _check_os_arch_keys = "check_os_arch_keys",
    _os_arch_pair = "os_arch_pair",
)

# Bazel 4.* doesn't support nested starlark functions, so we cannot simplify
# _fmt_flags() by defining it as a nested function.
def _fmt_flags(flags, toolchain_path_prefix):
    return [f.format(toolchain_path_prefix = toolchain_path_prefix) for f in flags]

# Turn C++ standard library include dirs into search-path flags. A single
# -nostdinc++ disables Clang's automatic libc++ header detection so our
# explicit -cxx-isystem entries are the only ones (see the long note where
# these are emitted).
def _cxx_isystem(cpp_system_includes):
    if not cpp_system_includes:
        return []
    return ["-nostdinc++"] + [
        flag
        for include in cpp_system_includes
        for flag in ("-cxx-isystem", include)
    ]

def _idirafter(includes):
    return [
        flag
        for include in includes
        for flag in ("-idirafter", include)
    ]

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

    # User-supplied flag templates substitute `{toolchain_path_prefix}` (and
    # friends) directly via _fmt_flags and expect a directory path ending in
    # '/'. Normalize the prefixes here so callers need not be precise. Internal
    # flags and path values use paths.join()/ensure_trailing_slash() and do not
    # depend on this.
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
        "none-riscv64": (
            "clang-riscv64-none",
            "riscv64",
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
        "-L" + paths.join(target_toolchain_path_prefix, "lib"),
        "-L" + paths.join(target_toolchain_path_prefix, "lib", target_system_name),
    ]

    # When building with memory sanitizer, the C++ standard library must be
    # instrumented too, otherwise msan reports false positives for any data
    # flowing through it. The instrumented libc++ is supplied through the
    # `libcxx_url`/`libcxx_sha256` attributes of the LLVM distribution repo,
    # which place it under `libcxx-msan/` next to the regular toolchain. These
    # paths are only used when msan is enabled (see the msan cc_feature below).
    msan_cpp_system_includes = [
        target_toolchain_path_prefix + "libcxx-msan/include/c++/v1/",
        target_toolchain_path_prefix + "libcxx-msan/include/" + target_system_name + "/c++/v1/",
    ]

    msan_link_flags = [
        "-L{}libcxx-msan/lib".format(target_toolchain_path_prefix),
        "-L{}libcxx-msan/lib/{}".format(target_toolchain_path_prefix, target_system_name),
    ]

    # MemorySanitizer compile+link flags. Unlike asan/ubsan/tsan, msan must swap
    # the C++ standard library for an instrumented libc++. On Linux this is
    # wired through a `msan` cc_feature (see the mutually-exclusive features
    # built near the cc_toolchain_config call), so that enabling it with
    # `--features=msan` is reset in the exec configuration (via --host_features)
    # and build tools stay uninstrumented.
    #
    # asan/ubsan/tsan are provided by rules_cc's stock sanitizer cc_features
    # (defined in unix_cc_toolchain_config) and are likewise enabled via
    # `--features=asan|ubsan|tsan`, so they are not wired up here.
    msan_sanitizer_flags = [
        "-fsanitize=memory",
        "-fsanitize-memory-track-origins",
        "-fsanitize-link-c++-runtime",
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

    # Standard-library-specific linker search paths (e.g. the sysroot's
    # libstdc++/libgcc directories) and the standard library archives
    # themselves. Kept separate from the general link_flags/link_libs so they
    # can be swapped for the instrumented libc++ when msan is enabled (see the
    # msan/nomsan cc_features below).
    stdlib_link_flags = []
    stdlib_link_libs = []

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

    # Allow callers to override the sysroot multiarch tuple (e.g. for
    # Yocto-style sysroots where libstdc++ headers live under
    # /usr/include/c++/<ver>/<multiarch> instead of the Debian
    # /usr/include/<multiarch>/c++/<ver> layout).
    multiarch_override = compiler_configuration.get("multiarch", "")
    if multiarch_override:
        multiarch = multiarch_override
    cxx_include_layout = compiler_configuration.get("cxx_include_layout", "") or "debian"

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

    # "dynamic-stdc++"[-<ver>] is libstdc++ linked dynamically rather than
    # statically. Normalize it back to the equivalent "stdc++" stdlib and
    # remember the choice so the linker picks libstdc++.so over libstdc++.a.
    dynamic_stdcxx = False
    if stdlib == "dynamic-stdc++":
        dynamic_stdcxx = True
        stdlib = "stdc++"
    elif stdlib.startswith("dynamic-stdc++-"):
        dynamic_stdcxx = True
        stdlib = "stdc++-" + stdlib[len("dynamic-stdc++-"):]

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
                "-L" + paths.join(sysroot_path, "usr/lib"),
                "-lc++",
                "-lc++abi",
                "-Bdynamic",
            ])
        else:
            # For single-platform builds, we can statically link the bundled
            # libraries.
            stdlib_link_libs.extend([
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

        stdlib_link_libs.extend([
            "-l:libc++.a",
            "-l:libc++abi.a",
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
        stdlib_link_flags.extend([
            "-L" + paths.join(target_toolchain_path_prefix, "lib"),
            "-L" + paths.join(target_toolchain_path_prefix, "lib", target_system_name),
        ])

        # Place the libstdc++ link in `link_libs` (after the object files) so
        # `--gc-sections` does not strip otherwise-unreferenced symbols (see
        # upstream #625). `dynamic_stdcxx` selects the shared variant.
        if dynamic_stdcxx:
            stdlib_link_libs.extend([
                "-l:libstdc++.so",
            ])
        else:
            stdlib_link_libs.extend([
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

            # libstdc++ headers live at /usr/include/c++/<ver> plus a
            # multiarch-specific directory whose layout differs between
            # Debian-style and Yocto-style sysroots.
            if cxx_include_layout == "yocto":
                multiarch_cpp_include = paths.join(sysroot_path, "usr/include/c++", libstdcxx_version, multiarch)
                stdlib_link_flags.extend([
                    "-B" + paths.ensure_trailing_slash(paths.join(sysroot_path, "usr/lib", multiarch, libstdcxx_version)),
                    "-Wl,-L" + paths.ensure_trailing_slash(paths.join(sysroot_path, "usr/lib", multiarch, libstdcxx_version)),
                ])
            else:
                multiarch_cpp_include = paths.join(sysroot_path, "usr/include", multiarch, "c++", libstdcxx_version)

            cpp_system_includes = [
                paths.join(sysroot_path, "usr/include/c++", libstdcxx_version),
                multiarch_cpp_include,
                paths.join(sysroot_path, "usr/include/c++", libstdcxx_version, "backward"),
            ]

            # Clang really wants C system header includes after C++ ones, so
            # drop the default C system paths and add the toolchain's builtin
            # headers via system_includes (-idirafter).
            nostdinc = True
            system_includes.append(toolchain_builtin_include)

            stdlib_link_flags.extend([
                "-L" + paths.join(sysroot_path, "usr/lib/gcc", multiarch, libstdcxx_version),
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
    #
    # Two include-path variants are computed: the configured stdlib's headers
    # and the instrumented libc++ that msan requires. msan always uses the
    # instrumented libc++ (an instrumented runtime requires an instrumented
    # standard library), so even when the configured stdlib is libstdc++ the
    # msan variant switches to the libc++ headers and drops -nostdinc (Clang
    # then derives the sysroot's C system includes from --sysroot, exactly as a
    # normal libc++ build does). On Linux the two variants are carried by the
    # msan/nomsan cc_features; on other platforms the configured-stdlib variant
    # is folded into compile_flags/cxx_flags at the cc_toolchain_config call.
    external_include_paths = []
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

    # Configured-stdlib include flags. With -nostdinc (libstdc++) Clang no
    # longer derives the sysroot's C system include paths from --sysroot, so
    # add them explicitly as -idirafter; they are searched after the compiler
    # builtin headers (system_includes) and the C++ standard library headers
    # (cpp_system_includes, via -cxx-isystem). Clang orders the -cxx-isystem
    # (CXXSystem) group after the -isystem (System) group, so the C library
    # headers must land in the later -idirafter (After) group for #include_next
    # from libstdc++ wrappers like <cstdlib> to resolve to them.
    normal_compile_include_flags = (["-nostdinc"] if nostdinc else []) + _idirafter(system_includes)
    if sysroot_path != None and nostdinc:
        normal_compile_include_flags = normal_compile_include_flags + _idirafter(external_include_paths)

    # Instrumented-libc++ include flags (msan). Uses the toolchain's builtin
    # headers via -idirafter with -nostdinc left off so the sysroot's C system
    # headers are auto-derived from --sysroot.
    msan_compile_include_flags = _idirafter([toolchain_builtin_include])

    # Two C++-standard-library variants: the configured stdlib (the "default"
    # branch below) and the instrumented libc++ that msan requires. On Linux
    # these are wired into mutually-exclusive cc_features so msan can be toggled
    # with `--features=msan` (which Bazel resets to `--host_features` in the
    # exec configuration, keeping build tools uninstrumented). MSan is only
    # supported on Linux, so elsewhere only the configured stdlib is used.
    default_cxx_isystem_flags = _cxx_isystem(cpp_system_includes)
    msan_cxx_isystem_flags = _cxx_isystem(msan_cpp_system_includes)
    default_link_search_flags = non_msan_link_flags if use_toolchain_libcxx_paths else stdlib_link_flags

    # msan forces libc++ (-stdlib=libc++) and links the instrumented libc++
    # instead of libstdc++/libgcc, so it additionally needs compiler-rt and
    # libunwind.
    msan_extra_link_flags = msan_link_flags + ["-stdlib=libc++", "-rtlib=compiler-rt", "-l:libunwind.a", "-lpthread", "-ldl"]
    msan_link_libs = ["-l:libc++.a", "-l:libc++abi.a"]

    is_linux = target_os == "linux"

    msan_feature_labels = []
    nomsan_feature_labels = []
    if is_linux:
        # msan is enabled via `--features=msan`. The `msan` cc_feature carries
        # the instrumented-libc++ and sanitizer flags; the default-stdlib flags
        # live in an always-on `<name>_nomsan_stdlib` feature whose args are
        # gated `none_of = [msan]`, so enabling msan swaps the configured C++
        # standard library for the instrumented libc++. Build tools run in the
        # exec config, where --features is reset to --host_features, so they
        # keep the default (uninstrumented) stdlib and stay uninstrumented.
        cc_args(
            name = name + "_msan_compile_args",
            actions = ["@rules_cc//cc/toolchains/actions:compile_actions"],
            args = msan_compile_include_flags + msan_sanitizer_flags,
        )
        cc_args(
            name = name + "_msan_cxx_args",
            actions = ["@rules_cc//cc/toolchains/actions:cpp_compile_actions"],
            args = msan_cxx_isystem_flags,
        )
        cc_args(
            name = name + "_msan_link_args",
            actions = ["@rules_cc//cc/toolchains/actions:link_actions"],
            args = msan_extra_link_flags + msan_link_libs + msan_sanitizer_flags,
        )
        cc_feature(
            name = name + "_msan",
            feature_name = "msan",
            args = [
                ":" + name + "_msan_compile_args",
                ":" + name + "_msan_cxx_args",
                ":" + name + "_msan_link_args",
            ],
        )
        msan_feature_labels = [":" + name + "_msan"]

        # Constraint satisfied only when the msan feature is NOT enabled. The
        # default-stdlib args below require it, so they are dropped under msan.
        cc_feature_set(
            name = name + "_msan_set",
            all_of = [":" + name + "_msan"],
        )
        cc_feature_constraint(
            name = name + "_not_msan",
            none_of = [":" + name + "_msan_set"],
        )

        nomsan_args = []
        if normal_compile_include_flags:
            cc_args(
                name = name + "_nomsan_compile_args",
                actions = ["@rules_cc//cc/toolchains/actions:compile_actions"],
                args = normal_compile_include_flags,
                requires_any_of = [":" + name + "_not_msan"],
            )
            nomsan_args.append(":" + name + "_nomsan_compile_args")
        if default_cxx_isystem_flags:
            cc_args(
                name = name + "_nomsan_cxx_args",
                actions = ["@rules_cc//cc/toolchains/actions:cpp_compile_actions"],
                args = default_cxx_isystem_flags,
                requires_any_of = [":" + name + "_not_msan"],
            )
            nomsan_args.append(":" + name + "_nomsan_cxx_args")
        nomsan_link_flags = default_link_search_flags + stdlib_link_libs
        if nomsan_link_flags:
            cc_args(
                name = name + "_nomsan_link_args",
                actions = ["@rules_cc//cc/toolchains/actions:link_actions"],
                args = nomsan_link_flags,
                requires_any_of = [":" + name + "_not_msan"],
            )
            nomsan_args.append(":" + name + "_nomsan_link_args")

        # Enabled by default via extra_enabled_features below (the cc_feature
        # rule always declares features disabled; the enabled state is set when
        # the toolchain wires it through extra_enabled_features).
        cc_feature(
            name = name + "_nomsan_stdlib",
            feature_name = name + "_nomsan_stdlib",
            args = nomsan_args,
        )
        nomsan_feature_labels = [":" + name + "_nomsan_stdlib"]

        # The stdlib include/link flags live in the msan/nomsan cc_features
        # above, so keep them out of the always-on baked flag lists.
        baked_compile_include_flags = []
        baked_cxx_isystem_flags = []
        baked_link_stdlib_flags = []
        baked_link_libs_stdlib = []
    else:
        # MSan is only supported on Linux (where it is wired through the `msan`
        # cc_feature above), so non-Linux toolchains always use the configured
        # standard library and never the instrumented libc++.
        baked_compile_include_flags = normal_compile_include_flags
        baked_cxx_isystem_flags = default_cxx_isystem_flags
        baked_link_stdlib_flags = default_link_search_flags
        baked_link_libs_stdlib = stdlib_link_libs

    # asan/ubsan/tsan are rules_cc's stock sanitizer cc_features, enabled via
    # `--features=asan|ubsan|tsan`. They link via a plain `-fsanitize=...`, which
    # does not pull Clang's C++ sanitizer runtime, so C++ programs fail to link
    # (e.g. ubsan's vptr handlers, __ubsan_*_type_cache). Augment each stock
    # feature with `-fsanitize-link-c++-runtime`; ubsan additionally gets
    # `-fsanitize=bounds` and `-fsanitize=nullability` (checks not in the default
    # `undefined` group).
    #
    # The augmentation flags are selected on config_settings that match
    # `--features=...` (see //toolchain/config). Keying on `--features` (rather
    # than a //toolchain/config flag) means the augmentation is reset to
    # `--host_features` in the exec configuration, so build tools stay
    # uninstrumented -- matching how the stock features themselves behave.
    sanitizer_compile_flags = select({
        str(Label("@toolchains_llvm//toolchain/config:use_ubsan")): [
            "-fsanitize=bounds",
            "-fsanitize=nullability",
        ],
        "//conditions:default": [],
    })
    sanitizer_link_flags = select({
        str(Label("@toolchains_llvm//toolchain/config:use_asan")): [
            "-fsanitize-link-c++-runtime",
        ],
        str(Label("@toolchains_llvm//toolchain/config:use_ubsan")): [
            "-fsanitize-link-c++-runtime",
            "-fsanitize=bounds",
            "-fsanitize=nullability",
        ],
        str(Label("@toolchains_llvm//toolchain/config:use_tsan")): [
            "-fsanitize-link-c++-runtime",
        ],
        "//conditions:default": [],
    })

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
        compile_flags = compile_flags + baked_compile_include_flags + sanitizer_compile_flags,
        fastbuild_compile_flags = fastbuild_compile_flags,
        dbg_compile_flags = dbg_compile_flags,
        opt_compile_flags = opt_compile_flags,
        conly_flags = conly_flags,
        cxx_flags = baked_cxx_isystem_flags + cxx_flags,
        link_flags = link_flags + select({str(Label("@toolchains_llvm//toolchain/config:use_libunwind")): libunwind_link_flags, "//conditions:default": []}) +
                     select({str(Label("@toolchains_llvm//toolchain/config:use_compiler_rt")): compiler_rt_link_flags, "//conditions:default": []}) +
                     # Standard library search paths and msan's libc++ forcing
                     # flags. On Linux these live in the msan/nomsan cc_features
                     # (baked_link_stdlib_flags is empty); elsewhere only the
                     # configured stdlib's search paths are used.
                     baked_link_stdlib_flags +
                     # asan/ubsan/tsan C++ runtime linking and ubsan's extra
                     # checks, selected on the matching --features (see above).
                     sanitizer_link_flags,
        archive_flags = archive_flags,
        # Standard library archives. On Linux these live in the cc_features
        # (baked_link_libs_stdlib is empty); elsewhere the configured stdlib's
        # archives.
        link_libs = baked_link_libs_stdlib + link_libs,
        opt_link_flags = opt_link_flags,
        unfiltered_compile_flags = unfiltered_compile_flags,
        coverage_compile_flags = coverage_compile_flags,
        coverage_link_flags = coverage_link_flags,
        supports_start_end_lib = supports_start_end_lib,
        builtin_sysroot = sysroot_path,
        extra_enabled_features = nomsan_feature_labels + extra_enabled_features,
        extra_known_features = msan_feature_labels + extra_known_features,
    )
