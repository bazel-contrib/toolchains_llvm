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
    "@bazel_tools//tools/cpp:unix_cc_toolchain_config.bzl",
    bazel_cc_toolchain_config = "cc_toolchain_config",
)

def cc_toolchain_config(name, cpu):
    if not (cpu == "darwin" or cpu == "k8"):
        fail("Unreachable")


    # A bunch of variables that get passed straight through to
    # `create_cc_toolchain_config_info`.
    toolchain_identifier, host_system_name, target_system_name, target_cpu, \
    target_libc, compiler, abi_version, abi_libc_version, builtin_sysroot = {
        "darwin": (
            "clang-darwin",
            "x86_64-apple-macosx",
            "x86_64-apple-macosx",
            "darwin",
            "macosx",
            "clang",
            "darwin_x86_64",
            "darwin_x86_64",
            "%{sysroot_path}",
        ),
        "k8": (
            "clang-linux",
            "x86_64",
            "x86_64-unknown-linux-gnu",
            "k8",
            "glibc_unknown",
            "clang",
            "clang",
            "glibc_unknown",
            "%{sysroot_path}",
        ),
    }[cpu]


    # Unfiltered compiler flags:
    unfiltered_compile_flags = [
        # Do not resolve our smylinked resource prefixes to real paths.
        "-no-canonical-prefixes",
        # Reproducibility
        "-Wno-builtin-macro-redefined",
        "-D__DATE__=\"redacted\"",
        "-D__TIMESTAMP__=\"redacted\"",
        "-D__TIME__=\"redacted\"",
        "-fdebug-prefix-map=%{toolchain_path_prefix}=%{debug_toolchain_path_prefix}",
    ]


    # Linker flags:
    if cpu == "k8":
        linker_flags = [
            # Use the lld linker.
            "-fuse-ld=lld",
            # The linker has no way of knowing if there are C++ objects; so we
            # always link C++ libraries.
            "-L%{toolchain_path_prefix}/lib",
            "-l:libc++.a",
            "-l:libc++abi.a",
            "-l:libunwind.a",
            # Compiler runtime features.
            "-rtlib=compiler-rt",
            # To support libunwind.
            "-lpthread",
            "-ldl",
            # Other linker flags.
            "-Wl,--build-id=md5",
            "-Wl,--hash-style=gnu",
            "-Wl,-z,relro,-z,now",
        ]
    elif cpu == "darwin":
        linker_flags = [
            # Difficult to guess options to statically link C++ libraries with
            # the macOS linker.
            "-lc++",
            "-lc++abi",
            "-headerpad_max_install_names",
            "-undefined",
            "dynamic_lookup",
        ]
    else:
        fail("Unreachable")

    link_flags = [
        "-lm",
        "-no-canonical-prefixes",
    ] + linker_flags

    opt_link_flags = ["-Wl,--gc-sections"] if cpu == "k8" else []


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
        "%{toolchain_path_prefix}include/c++/v1",
        "%{toolchain_path_prefix}lib/clang/%{llvm_version}/include",
        "%{toolchain_path_prefix}lib64/clang/%{llvm_version}/include",
    ]

    if (cpu == "k8"):
        cxx_builtin_include_directories += [
            "%{sysroot_prefix}/include",
            "%{sysroot_prefix}/usr/include",
            "%{sysroot_prefix}/usr/local/include",
        ] + [
            %{k8_additional_cxx_builtin_include_directories}
        ]
    elif (cpu == "darwin"):
        cxx_builtin_include_directories += [
            "%{sysroot_prefix}/usr/include",
            "%{sysroot_prefix}/System/Library/Frameworks",
            "/Library/Frameworks",
        ] + [
            %{darwin_additional_cxx_builtin_include_directories}
        ]
    else:
        fail("Unreachable")


    ## NOTE: make variables are missing here; unix_cc_toolchain_config doesn't
    ## pass these to `create_cc_toolchain_config_info`.

    # Start-end group linker support:
    # This was added to `lld` in this patch: http://reviews.llvm.org/D18814
    #
    # The oldest version of LLVM that we support is 6.0.0 which was released
    # after the above patch was merged, so we just set this to `True`:
    supports_start_end_lib = True


    # Tool paths:
    # `llvm-strip` was introduced in V7 (https://reviews.llvm.org/D46407):
    LLVM_MAJOR_VER = "%{llvm_version}".split(".")
    LLVM_MAJOR_VER = int(LLVM_MAJOR_VER[0]) if len(LLVM_MAJOR_VER) else 0
    strip_binary = \
        "%{tools_path_prefix}bin/llvm-strip" if LLVM_MAJOR_VER >= 7 else "/usr/bin/strip"

    tool_paths = {
        "cpp": "%{tools_path_prefix}bin/clang-cpp",
        "dwp": "%{tools_path_prefix}bin/llvm-dwp",
        "gcov": "%{tools_path_prefix}bin/llvm-profdata",
        "llvm-cov": "%{tools_path_prefix}bin/llvm-cov",
        "nm": "%{tools_path_prefix}bin/llvm-nm",
        "objcopy": "%{tools_path_prefix}bin/llvm-objcopy",
        "objdump": "%{tools_path_prefix}bin/llvm-objdump",
        "strip": strip_binary,
    }
    tool_paths.update({
        "k8": {
            "ld": "%{tools_path_prefix}bin/ld.lld",
            "gcc": "%{tools_path_prefix}bin/clang",
            "objdump": "%{tools_path_prefix}bin/llvm-ar",
        },
        "darwin": {
            # ld.lld Mach-O support is still experimental:
            "ld": "%{tools_path_prefix}bin/ld",
            # See `cc_wrapper.sh.tpl` for details:
            "gcc": "%{tools_path_prefix}bin/cc_wrapper.sh",
            # No idea why we use `libtool` instead of `llvm-ar` on macOS:
            "ar": "/usr/bin/libtool",
        },
    }[cpu])


    # Source: https://cs.opensource.google/bazel/bazel/+/master:tools/cpp/unix_cc_toolchain_config.bzl
    bazel_cc_toolchain_config(
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

        # This was only added in bazel v4.0.0.
        #
        # See: https://github.com/bazelbuild/bazel/commit/da345f1f249ebf28bec88c6e0d63260dfaef14e9
        **(
            {"builtin_sysroot": builtin_sysroot}
            if int("%{bazel_version}".split(".")[0]) >= 4
            else {}
        )
    )
