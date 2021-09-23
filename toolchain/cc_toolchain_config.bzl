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
        cc_wrapper_prefix,
        sysroot_path,
        additional_include_dirs,
        llvm_version):
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
        "linux-x86_64": (
            "clang-x86_64-linux",
            "x86_64-unknown-linux-gnu",
            "k8",
            "glibc_unknown",
            "clang",
            "clang",
            "glibc_unknown",
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
    }[target_os_arch_key]

    # Unfiltered compiler flags:
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

    # Linker flags:
    if host_os == "darwin" and not is_xcompile:
        # lld is experimental for Mach-O, so we use the native ld64 linker.
        use_lld = False
        linker_flags = [
            "-headerpad_max_install_names",
            "-undefined",
            "dynamic_lookup",
        ]
    else:
        # We prefer the lld linker.
        # Note that for xcompiling from darwin to linux, the native ld64 is
        # not an option because it is not a cross-linker, so lld is the
        # only option.
        use_lld = True
        linker_flags = [
            "-fuse-ld=lld",
            "-Wl,--build-id=md5",
            "-Wl,--hash-style=gnu",
            "-Wl,-z,relro,-z,now",
        ]

    # The linker has no way of knowing if there are C++ objects; so we
    # always link C++ libraries.
    if host_os == "linux" and not is_xcompile:
        # For single-platform linux builds, we can statically link the bundled
        # libraries.
        linker_flags.extend([
            "-L{}lib".format(toolchain_path_prefix),
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
        # For xcompile, we expect to pick up these libraries from the sysroot.
        # TODO: For single-platform darwin builds, we can statically link the
        # bundled libraries but I do not know the right flags to make it
        # happen.
        linker_flags.extend([
            "-lc++",
            "-lc++abi",
        ])

    link_flags = [
        "-lm",
        "-no-canonical-prefixes",
    ] + linker_flags

    opt_link_flags = ["-Wl,--gc-sections"] if target_os == "linux" else []

    # Default compiler flags:
    compile_flags = [
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

    cxx_flags = ["-std=c++17", "-stdlib=libc++"]

    # Coverage flags:
    coverage_compile_flags = ["-fprofile-instr-generate", "-fcoverage-mapping"]
    coverage_link_flags = ["-fprofile-instr-generate"]

    ## NOTE: framework paths is missing here; unix_cc_toolchain_config
    ## doesn't seem to have a feature for this.

    # C++ built-in include directories:
    cxx_builtin_include_directories = [
        toolchain_path_prefix + "include/c++/v1",
        toolchain_path_prefix + "lib/clang/{}/include".format(llvm_version),
        toolchain_path_prefix + "lib64/clang/{}/include".format(llvm_version),
    ]

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

    cxx_builtin_include_directories.extend(additional_include_dirs)

    ## NOTE: make variables are missing here; unix_cc_toolchain_config doesn't
    ## pass these to `create_cc_toolchain_config_info`.

    # Tool paths:
    # `llvm-strip` was introduced in V7 (https://reviews.llvm.org/D46407):
    llvm_version = llvm_version.split(".")
    llvm_major_ver = int(llvm_version[0]) if len(llvm_version) else 0
    strip_binary = (tools_path_prefix + "bin/llvm-strip") if llvm_major_ver >= 7 else "/usr/bin/strip"

    tool_paths = {
        # TODO: The command line formed on darwin does not work with llvm-ar.
        "ar": tools_path_prefix + "bin/llvm-ar" if host_os != "darwin" else "/usr/bin/libtool",
        "cpp": tools_path_prefix + "bin/clang-cpp",
        "dwp": tools_path_prefix + "bin/llvm-dwp",
        "gcc": cc_wrapper_prefix + "bin/cc_wrapper.sh",
        "gcov": tools_path_prefix + "bin/llvm-profdata",
        "ld": tools_path_prefix + "bin/ld.lld" if use_lld else "/usr/bin/ld",
        "llvm-cov": tools_path_prefix + "bin/llvm-cov",
        "nm": tools_path_prefix + "bin/llvm-nm",
        "objcopy": tools_path_prefix + "bin/llvm-objcopy",
        "objdump": tools_path_prefix + "bin/llvm-objdump",
        "strip": strip_binary,
    }

    # Start-end group linker support:
    # This was added to `lld` in this patch: http://reviews.llvm.org/D18814
    #
    # The oldest version of LLVM that we support is 6.0.0 which was released
    # after the above patch was merged, so we just set this to `True` when
    # `lld` is being used as the linker.
    supports_start_end_lib = use_lld

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
        # link_libs = _,
        opt_link_flags = opt_link_flags,
        unfiltered_compile_flags = unfiltered_compile_flags,
        coverage_compile_flags = coverage_compile_flags,
        coverage_link_flags = coverage_link_flags,
        supports_start_end_lib = supports_start_end_lib,
        builtin_sysroot = sysroot_path,
    )
