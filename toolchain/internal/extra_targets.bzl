"""
Helpers for configuring toolchains that target platforms different than the
host platform.
"""

load("//toolchain/internal/extra_targets:wasi.bzl", "get_wasi_sysroot", "install_wasi_compiler_rt")

# A mapping from [LLVM target triple][tt] [architectures][a] to Bazel platform
# [CPU][c]s.
#
# [tt]: https://llvm.org/doxygen/Triple_8h_source.html
# [a]: https://llvm.org/doxygen/classllvm_1_1Triple.html#a547abd13f7a3c063aa72c8192a868154
# [c]: https://github.com/bazelbuild/platforms/blob/main/cpu/BUILD
LLVM_ARCH_TO_BAZEL_PLATFORM_CPU = {
    # ARM (little endian): arm, armv.*, xscale
    # -> ARM subarch table

    # ARM (big endian): armeb
    "armeb":          None,
    # AArch64 (little endian): aarch64
    "aarch64":        "aarch64",
    # AArch64 (big endian): aarch64_be
    "aarch64_be":     None,
    # AArch64 (little endian) ILP32: aarch64_32
    "aarch64_32":     "arm64_32",
    # ARC: Synopsys ARC
    "arc":            None,
    # AVR: Atmel AVR microcontroller
    "avr":            None,
    # eBPF or extended BPF or 64-bit BPF (little endian)
    "bpfel":          None,
    # eBPF or extended BPF or 64-bit BPF (big endian)
    "bpfeb":          None,
    # CSKY: csky
    "csky":           None,
    # Hexagon: hexagon
    "hexagon":        None,
    # M68k: Motorola 680x0 family
    "m68k":           None,
    # MIPS: mips, mipsallegrex, mipsr6
    "mips":           None,
    "mipsallegrex":   None,
    "mipsr6":         None,
    # MIPSEL: mipsel, mipsallegrexe, mipsr6el
    "mipsel":         None,
    "mipsallegrexe":  None,
    "mipsr6el":       None,
    # MIPS64: mips64, mips64r6, mipsn32, mipsn32r6
    "mips64":         "mips64",
    "mips64r6":       "mips64",
    "mipsn32":        "mips64",
    "mipsn32r6":      "mips64",
    # MIPS64EL: mips64el, mips64r6el, mipsn32el, mipsn32r6el
    "mips64el":       None,
    "mips64r6el":     None,
    "mipsn32el":      None,
    "mipsn32r6el":    None,
    # MSP430: msp430
    "msp430":         None,
    # PPC: powerpc
    "ppc":            "ppc",
    # PPCLE: powerpc (little endian)
    "ppcle":          None,
    # PPC64: powerpc64, ppu
    "ppc64":          None,
    # PPC64LE: powerpc64le
    "ppc64le":        None,
    # R600: AMD GPUs HD2XXX - HD6XXX
    "r600":           None,
    # AMDGCN: AMD GCN GPUs
    "amdgcn":         None,
    # RISC-V (32-bit): riscv32
    "riscv32":        None,
    # RISC-V (64-bit): riscv64
    "riscv64":        "riscv64",
    # Sparc: sparc
    "sparc":          None,
    # Sparcv9: Sparcv9
    "sparcv9":        None,
    # Sparc: (endianness = little). NB: 'Sparcle' is a CPU variant
    "sparcel":        None,
    # SystemZ: s390x
    "systemz":        "s390x",
    "s390x":          "s390x",
    # TCE (http://tce.cs.tut.fi/): tce
    "tce":            None,
    # TCE little endian (http://tce.cs.tut.fi/): tcele
    "tcele":          None,
    # Thumb (little endian): thumb, thumbv.*
    # -> ARM subarch table

    # Thumb (big endian): thumbeb
    "thumbeb":        "arm",
    # X86: i[3-9]86
    "x86":            ["i386", "x86_32"],
    "i386":           ["i386", "x86_32"],
    "i486":           ["i386", "x86_32"],
    "i586":           ["i386", "x86_32"],
    "i686":           ["i386", "x86_32"],
    "i786":           ["i386", "x86_32"],
    "i886":           ["i386", "x86_32"],
    "i986":           ["i386", "x86_32"],
    # X86-64: amd64, x86_64
    "x86_64":         "x86_64",
    "amd64":          "x86_64",
    # XCore: xcore
    "xcore":          None,
    # NVPTX: 32-bit
    "nvptx":          None,
    # NVPTX: 64-bit
    "nvptx64":        None,
    # le32: generic little-endian 32-bit CPU (PNaCl)
    "le32":           None,
    # le64: generic little-endian 64-bit CPU (PNaCl)
    "le64":           None,
    # AMDIL
    "amdil":          None,
    # AMDIL with 64-bit pointers
    "amdil64":        None,
    # AMD HSAIL
    "hsail":          None,
    # AMD HSAIL with 64-bit pointers
    "hsail64":        None,
    # SPIR: standard portable IR for OpenCL 32-bit version
    "spir":           None,
    # SPIR: standard portable IR for OpenCL 64-bit version
    "spir64":         None,
    # Kalimba: generic kalimba
    "kalimba":        None,
    # SHAVE: Movidius vector VLIW processors
    "shave":          None,
    # Lanai: Lanai 32-bit
    "lanai":          None,
    # WebAssembly with 32-bit pointers
    "wasm32":         "wasm32",
    # WebAssembly with 64-bit pointers
    "wasm64":         "wasm64",
    # 32-bit RenderScript
    "renderscript32": None,
    # 64-bit RenderScript
    "renderscript64": None,
    # NEC SX-Aurora Vector Engine
    "ve":             None,
}

# For `armv.*` and `thumbv.*`.
#
# Not all of these sub-architectures are allowed for both `arm` and `thumb`
# target triples but this is a good enough for what we're doing.
#
# See this file for some context: https://github.com/llvm/llvm-project/blob/main/llvm/lib/Support/ARMTargetParser.cpp
# And this: https://llvm.org/doxygen/classllvm_1_1Triple.html#a9ffca842bbaefcf99484f59a83b618d4
#
# TODO: verify that these are right
LLVM_ARCH_TO_BAZEL_PLATFORM_CPU_ARM_SUBARCHS = {
    "v8.7a":      "aarch64",
    "v8.6a":      "aarch64",
    "v8.5a":      "aarch64",
    "v8.4a":      "aarch64",
    "v8.3a":      "aarch64",
    "v8.2a":      "aarch64",
    "v8.1a":      "aarch64",
    "v8":         "aarch64",
    "v8r":        None,
    "v8m.base":   "armv8-m",
    "v8m.main":   "armv8-m",
    "v8.1m.main": "armv8-m",
    "v7":         "armv7",
    # This is questionable; `hf` is typically in the env part of the triple so
    # we could check for that and then pick between `armv7e-mf` and `armv7e-m`.
    #
    # Or we could just say the compiler supports both (which *is* true).
    #
    # Eventually we should probably do the former though (TODO).
    #
    # Ideally `arm-fpu` would be it's own constraint.
    "v7em":       ["armv7e-m", "armv7e-mf"],
    "v7m":        "armv7m",
    "v7s":        None,
    "v7k":        "armv7k",
    "v7ve":       None,
    "v6":         None,
    "v6m":        "armv6-m",
    "v6k":        None,
    "v6t2":       None,
    "v5":         None,
    "v5te":       None,
    "v4t":        None,

    # For arm64e:
    "64e":       "arm64e"
}

# A mapping from [LLVM target triple][tt] [operating systems][o] to Bazel
# platform [operating systems][baz-o] constraints.
#
# [tt]: https://llvm.org/doxygen/Triple_8h_source.html
# [o]: https://llvm.org/doxygen/classllvm_1_1Triple.html#a3cfefc755ab656000934f91193afb1cd
# [baz-o]: https://github.com/bazelbuild/platforms/blob/main/os/BUILD
#
# See: https://github.com/llvm/llvm-project/blob/944dfa4975e8d55ca9d97f6eb7222ff1d0f7291a/llvm/lib/Support/Triple.cpp#L505-L541
LLVM_OS_TO_BAZEL_PLATFORM_OS = {
    "ananas":     None,
    "cloudabi":   None,
    "darwin":     None,
    "dragonfly":  None,
    "freebsd":    "freebsd",
    "fuchsia":    None,
    "ios":        "ios",
    "kfreebsd":   None,
    "linux":      "linux",
    "lv2":        None,
    "macos":      "macos",
    "netbsd":     None,
    "openbsd":    "openbsd",
    "solaris":    None,
    "win32":      None,
    "windows":    "windows",
    "zos":        None,
    "haiku":      None,
    "minix":      None,
    "rtems":      None,
    "nacl":       None,
    "aix":        None,
    "cuda":       None,
    "nvcl":       None,
    "amdhsa":     None,
    "ps4":        None,
    "elfiamcu":   None,
    "tvos":       "tvos",
    "watchos":    "watchos",
    "mesa3d":     None,
    "contiki":    None,
    "amdpal":     None,
    "hermit":     None,
    "hurd":       None,
    "wasi":       "wasi",
    "emscripten": None,

    # No OS; bare metal.
    "none":       "none",
}

# A mapping from [LLVM target triple][tt] [environments][e] to Bazel
# platform constraints.
#
# [tt]: https://llvm.org/doxygen/Triple_8h_source.html
# [e]: https://llvm.org/doxygen/classllvm_1_1Triple.html#a1778f5c464f88710033f7e11e84a9324
#
# See: https://github.com/llvm/llvm-project/blob/944dfa4975e8d55ca9d97f6eb7222ff1d0f7291a/llvm/lib/Support/Triple.cpp#L544-L568
LLVM_ENV_TO_BAZEL_PLATFORM_CONSTRAINTS = {
    "eabihf":     None,
    "eabi":       None,
    "gnuabin32":  None,
    "gnuabi64":   None,
    "gnueabihf":  None,
    "gnueabi":    None,
    "gnux32":     None,
    "gnu_ilp32":  None,
    "code16":     None,
    "gnu":        None,
    "android":    "os:android",
    "musleabihf": None,
    "musleabi":   None,
    "muslx32":    None,
    "musl":       None,
    "msvc":       None,
    "itanium":    None,
    "cygnus":     None,
    "coreclr":    None,
    "simulator":  None,
    "macabi":     None,
}

def prefix_list_or_single(constraint_base, constraints):
    if type(constraints) == "list":
        return ["{}{}".format(constraint_base, c) for c in constraints]
    elif constraints:
        return ["{}{}".format(constraint_base, constraints)]
    else:
        return []

def cpu_names(arch):
    constraints = None

    if arch.startswith("arm"):
        constraints = LLVM_ARCH_TO_BAZEL_PLATFORM_CPU_ARM_SUBARCHS.get(arch[len("arm"):])

        # If a more specific constraint isn't available, fall back to "arm":
        if not constraints: constraints = "arm"
    elif arch.startswith("thumb"):
        constraints = LLVM_ARCH_TO_BAZEL_PLATFORM_CPU_ARM_SUBARCHS.get(arch[len("thumb"):])
    else:
        if arch not in LLVM_ARCH_TO_BAZEL_PLATFORM_CPU:
            fail("Unrecognized architecture: `{}`.".format(arch))
        constraints = LLVM_ARCH_TO_BAZEL_PLATFORM_CPU.get(arch)

    return prefix_list_or_single("", constraints)

def cpu_constraints(arch):
    return prefix_list_or_single("@platforms//cpu:", cpu_names(arch))

def os_constraints(os):
    # NOTE: we do not error if the given OS name is not in our table.
    constraints = LLVM_OS_TO_BAZEL_PLATFORM_OS.get(os)

    return prefix_list_or_single("@platforms//os:", constraints)

def env_constraints(env):
    # `env` is optional:
    if not env: return []

    if env in LLVM_ENV_TO_BAZEL_PLATFORM_CONSTRAINTS:
        constraints = LLVM_ENV_TO_BAZEL_PLATFORM_CONSTRAINTS[env]

        return prefix_list_or_single("@platforms//", constraints)
    else:
        fail("Unrecognized environment in target triple: `{}`.".format(env))

def split_target_triple(triple):
    """Splits a target triple into its parts.

    Args:
      triple: the triple to split

    Returns:
      the triple's constituent architecture, vendor, operating system, and env
      parts
    """

    # [As per LLVM](https://llvm.org/doxygen/Triple_8h_source.html), a triple
    # consists of: `arch-vendor-operating_system(-environment)?`.
    parts = triple.split("-")

    if len(parts) == 3:
        parts.append(None)
    if len(parts) != 4:
        fail("`{}` is not a valid target triple.".format(triple))

    return parts

def target_triple_to_constraints(triple):
    arch, _vendor, os, env = split_target_triple(triple)

    # NOTE: we don't generate constraints from the vendor part.
    return cpu_constraints(arch) + os_constraints(os) + env_constraints(env)

# TODO: this kind of logic is what needs to be filled in for other targets:

README = "\n\nSee https://github.com/grailbio/bazel-toolchain/blob/master/README.md#setting-up-toolchains-for-other-targets" + \
    " for more information."

def overrides_for_target(rctx, triple):
    arch, _vendor, os, _env = split_target_triple(triple)
    llvm_version = rctx.attr.llvm_version
    llvm_major_version = int(llvm_version.split(".")[0])

    if arch == "wasm32" or arch == "wasm64":
        overrides = {
            "omit_hosted_linker_flags": True,
            "omit_cxx_stdlib_flag": True,

            # libtool doesn't seem to be able to handle wasm
            "use_llvm_ar_instead_of_libtool_on_macos": True,

            # lld ultimately shells out to `wasm-ld` which does *not* support
            # start end groups for libraries which is why this override is
            # important
            "custom_linker_tool": {
                "darwin": "wasm-ld",
                "k8": "wasm-ld",
            },

            # wasm-ld doesn't understand `-l:libfoo.a` style syntax unfortunately
            "prefer_static_cxx_libs_on_linux_hosts": False,

            # not yet supported on wasm; see: https://github.com/WebAssembly/tool-conventions/issues/133
            "linker_include_build_id_on_linux_hosts": False,

            # not support by `wasm-ld`:
            "linker_use_gnu_hash_style_on_linux_hosts": False,

            # not applicable for wasm (we're not dynamically linking):
            "linker_use_elf_hardening_so_flags_on_linux_hosts": False,
        }

        # `clang-12` specifically uses `-mthread-model posix` by default
        # which causes `libc++` to define `__STDCPP_THREADS__` which doesn't
        # play nice with the WASI libc defines.
        #
        # This is "fixed" in newer versions of LLVM:
        # https://reviews.llvm.org/D96091
        #
        # But for `clang-12` we need to pass in `-mthread-model single`.
        #
        # See: https://github.com/WebAssembly/wasi-sdk/issues/173
        if llvm_major_version == 12:
            overrides.update({
                "extra_compile_flags": ["-mthread-model", "single"],
            })

        return overrides
    else:
        print(
            ("`{}` support has not been added to bazel-toolchain; you may " +
            "need to manually adjust compiler flags and toolchain " +
            "configurations yourself!" + README).format(triple)
        )

        return {}

def sysroot_for_target(rctx, triple):
    arch, _vendor, os, _env = split_target_triple(triple)

    if not rctx.path("sysroots").exists:
        rctx.file(
            "sysroots/BUILD",
            content = "",
            executable = False,
        )

    # NOTE: I think this sysroot can be used on `wasm32-unknown-unknown` too;
    # it seems to gate all wasi functionality correctly.
    if arch == "wasm32" and (os == "wasi" or os == "unknown" or os == "none"):
        return get_wasi_sysroot(rctx, for_non_wasi = os != "wasi")
    else:
        print(
            ("`{}` support has not been added to bazel-toolchain; you may " +
            "need to find a sysroot and manually configure a toolchain " +
            "yourself!" + README).format(triple)
        )

        return None

# Runs *after* the toolchain has been fetched and extracted.
def extra_target_setup(rctx, triple):
    arch, _vendor, os, _env = split_target_triple(triple)

    # TODO: I think compiler_rt for wasi can be used on
    # `wasm32-unknown-unknown` too.
    if arch == "wasm32" and (os == "wasi" or os == "unknown" or os == "none"):
        install_wasi_compiler_rt(rctx, for_non_wasi = os != "wasi")
    else:
        print(
            ("`{}` support has not been added to bazel-toolchain; you may " +
            "need to grab compiler_rt or do additional toolchain setup " +
            "yourself!" + README).format(triple)
        )
