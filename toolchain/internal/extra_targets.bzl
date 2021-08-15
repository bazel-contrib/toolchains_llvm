"""
Helpers for configuring toolchains that target platforms different than the
host platform.
"""

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

# and
# [OS][o] constraints.

def cpu_constraint(arch):
    constraint = None

    if arch.startswith("arm"):
        constraint = LLVM_ARCH_TO_BAZEL_PLATFORM_CPU_ARM_SUBARCHS.get(arch[len("arm"):])

        # If a more specific constraint isn't available, fall back to "arm":
        if not constraint: constraint = "arm"
    elif arch.startswith("thumb"):
        constraint = LLVM_ARCH_TO_BAZEL_PLATFORM_CPU_ARM_SUBARCHS.get(arch[len("thumb"):])
    else:
        if arch not in LLVM_ARCH_TO_BAZEL_PLATFORM_CPU:
            fail("Unrecognized architecture: `{}`.".format(arch))
        constraint = LLVM_ARCH_TO_BAZEL_PLATFORM_CPU.get(arch)

    if type(constraint) == "list":
        return ["@platforms//cpu:".format(c) for c in constraint]
    elif constraint:
        return "@platforms//cpu:".format(constraint)
    else:
        return []

def target_triple_to_constraints(triple):
    # [As per LLVM](https://llvm.org/doxygen/Triple_8h_source.html), a triple
    # consists of: `arch-vendor-operating_system(-environment)?`.
    parts = triple.split("-")

    if len(parts) == 3: parts.append(None)
    if len(parts) != 4: fail("`{}` is not a valid target triple.")
    arch, vendor, os, env = parts


