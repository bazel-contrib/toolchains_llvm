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

major_version: "local"
minor_version: ""
default_target_cpu: "same_as_host"

default_toolchain {
  cpu: "k8"
  toolchain_identifier: "clang-linux"
}

default_toolchain {
  cpu: "darwin"
  toolchain_identifier: "clang-darwin"
}

toolchain {
  toolchain_identifier: "clang-linux"
  abi_version: "local"
  abi_libc_version: "local"
  compiler: "clang"
  host_system_name: "local"
  needsPic: false
  supports_gold_linker: false
  supports_incremental_linker: false
  supports_fission: false
  supports_interface_shared_objects: false
  supports_normalizing_ar: false
  supports_start_end_lib: true
  target_libc: "local"
  target_cpu: "k8"
  target_system_name: "local"

  builtin_sysroot: ""

  # Working with symlinks; anticipated to be a future default.
  compiler_flag: "-no-canonical-prefixes"
  linker_flag: "-no-canonical-prefixes"

  # Reproducibility.
  unfiltered_cxx_flag: "-Wno-builtin-macro-redefined"
  unfiltered_cxx_flag: "-D__DATE__=\"redacted\""
  unfiltered_cxx_flag: "-D__TIMESTAMP__=\"redacted\""
  unfiltered_cxx_flag: "-D__TIME__=\"redacted\""

  # Security
  compiler_flag: "-U_FORTIFY_SOURCE"
  compiler_flag: "-fstack-protector"
  compiler_flag: "-fcolor-diagnostics"
  compiler_flag: "-fno-omit-frame-pointer"

  # Diagnostics
  compiler_flag: "-Wall"

  # C++
  cxx_flag: "-std=c++11"
  # The linker has no way of knowing if there are C++ objects; so we always link C++ libraries.
  linker_flag: "%{toolchain_path_prefix}lib/libc++.a"
  linker_flag: "%{toolchain_path_prefix}lib/libc++abi.a"
  linker_flag: "%{toolchain_path_prefix}lib/libunwind.a"
  cxx_flag: "-DLIBCXX_USE_COMPILER_RT=YES"
  linker_flag: "-rtlib=compiler-rt"
  linker_flag: "-lpthread"
  linker_flag: "-ldl" # For libunwind

  # Linker
  linker_flag: "-lm"
  linker_flag: "-fuse-ld=lld"
  linker_flag: "-Wl,--build-id=md5"
  linker_flag: "-Wl,--hash-style=gnu"

  # Syntax for include directories is mentioned at:
  # https://github.com/bazelbuild/bazel/blob/d61a185de8582d29dda7525bb04d8ffc5be3bd11/src/main/java/com/google/devtools/build/lib/rules/cpp/CcToolchain.java#L125
  cxx_builtin_include_directory: "%{toolchain_path_prefix}include/c++/v1"
  cxx_builtin_include_directory: "%{toolchain_path_prefix}lib/clang/%{llvm_version}/include"
  cxx_builtin_include_directory: "/include"
  cxx_builtin_include_directory: "/usr/include"
  cxx_builtin_include_directory: "/usr/local/include"
  compiler_flag: "-isystem%{toolchain_path_prefix}include/c++/v1"
  compiler_flag: "-isystem%{toolchain_path_prefix}lib/clang/%{llvm_version}/include"

  objcopy_embed_flag: "-I"
  objcopy_embed_flag: "binary"

  compiler_flag: "-B%{toolchain_path_prefix}bin"
  tool_path {name: "ld" path: "%{tools_path_prefix}bin/ld.lld" }
  tool_path {name: "cpp" path: "%{tools_path_prefix}bin/clang-cpp" }
  tool_path {name: "dwp" path: "%{tools_path_prefix}bin/llvm-dwp" }
  tool_path {name: "gcov" path: "%{tools_path_prefix}bin/llvm-profdata" }
  tool_path {name: "nm" path: "%{tools_path_prefix}bin/llvm-nm" }
  tool_path {name: "objcopy" path: "%{tools_path_prefix}bin/llvm-objcopy" }
  tool_path {name: "objdump" path: "%{tools_path_prefix}bin/llvm-objdump" }
  tool_path {name: "strip" path: "/usr/bin/strip" }
  tool_path {name: "gcc" path: "%{tools_path_prefix}bin/clang" }
  tool_path {name: "ar" path: "%{tools_path_prefix}bin/llvm-ar" }

  compilation_mode_flags {
    mode: DBG
    compiler_flag: "-g"
  }

  compilation_mode_flags {
    mode: OPT
    compiler_flag: "-g0"
    compiler_flag: "-O2"
    compiler_flag: "-D_FORTIFY_SOURCE=1"
    compiler_flag: "-DNDEBUG"
    compiler_flag: "-ffunction-sections"
    compiler_flag: "-fdata-sections"
    linker_flag: "-Wl,--gc-sections"
  }

  linking_mode_flags { mode: DYNAMIC }

  feature {
    name: "coverage"
  }
  feature {
    name: "llvm_coverage_map_format"
    flag_set {
      action: "preprocess-assemble"
      action: "c-compile"
      action: "c++-compile"
      action: "c++-module-compile"
      flag_group {
        flag: "-fprofile-instr-generate"
        flag: "-fcoverage-mapping"
        flag: "-g"
      }
    }
    flag_set {
      action: "c++-link-dynamic-library"
      action: "c++-link-nodeps-dynamic-library"
      action: "c++-link-executable"
      flag_group {
        flag: "-fprofile-instr-generate"
      }
    }
    requires {
      feature: "coverage"
    }
  }
  feature {
    name: "gcc_coverage_map_format"
    flag_set {
      action: "preprocess-assemble"
      action: "c-compile"
      action: "c++-compile"
      action: "c++-module-compile"
      flag_group {
        flag: "-fprofile-arcs"
        flag: "-ftest-coverage"
        flag: "-g"
      }
    }
    flag_set {
      action: "c++-link-dynamic-library"
      action: "c++-link-nodeps-dynamic-library"
      action: "c++-link-executable"
      flag_group {
        flag: "-lgcov"
      }
    }
    requires {
      feature: "coverage"
    }
  }
}

toolchain {
  toolchain_identifier: "clang-darwin"
  host_system_name: "x86_64-apple-macosx"
  target_system_name: "x86_64-apple-macosx"
  target_cpu: "darwin"
  target_libc: "macosx"
  compiler: "clang"
  abi_version: "darwin_x86_64"
  abi_libc_version: "darwin_x86_64"
  needsPic: true

  builtin_sysroot: ""

  # Working with symlinks
  compiler_flag: "-no-canonical-prefixes"
  linker_flag: "-no-canonical-prefixes"

  # Reproducibility.
  unfiltered_cxx_flag: "-Wno-builtin-macro-redefined"
  unfiltered_cxx_flag: "-D__DATE__=\"redacted\""
  unfiltered_cxx_flag: "-D__TIMESTAMP__=\"redacted\""
  unfiltered_cxx_flag: "-D__TIME__=\"redacted\""

  # Security
  compiler_flag: "-D_FORTIFY_SOURCE=1"
  compiler_flag: "-fstack-protector"
  compiler_flag: "-Wthread-safety"
  compiler_flag: "-Wself-assign"
  compiler_flag: "-fno-omit-frame-pointer"

  # Diagnostics
  compiler_flag: "-fcolor-diagnostics"
  compiler_flag: "-Wall"

  # C++
  cxx_flag: "-std=c++11"
  # The linker has no way of knowing if there are C++ objects; so we always link C++ libraries.
  linker_flag: "%{toolchain_path_prefix}lib/libc++.a"
  linker_flag: "%{toolchain_path_prefix}lib/libc++abi.a"
  linker_flag: "-lpthread"

  # Linker
  linker_flag: "-lm"
  linker_flag: "-headerpad_max_install_names"

  # Syntax for include directories is mentioned at:
  # https://github.com/bazelbuild/bazel/blob/d61a185de8582d29dda7525bb04d8ffc5be3bd11/src/main/java/com/google/devtools/build/lib/rules/cpp/CcToolchain.java#L125
  cxx_builtin_include_directory: "%{toolchain_path_prefix}include/c++/v1"
  cxx_builtin_include_directory: "%{toolchain_path_prefix}lib/clang/%{llvm_version}/include"
  cxx_builtin_include_directory: "/usr/include"
  cxx_builtin_include_directory: "/usr/include/linux"
  cxx_builtin_include_directory: "/System/Library/Frameworks"
  cxx_builtin_include_directory: "/Library/Frameworks"
  #cxx_builtin_include_directory: "/Applications/Xcode.app/Contents/Developer"
  compiler_flag: "-isystem%{toolchain_path_prefix}include/c++/v1"
  compiler_flag: "-isystem%{toolchain_path_prefix}lib/clang/%{llvm_version}/include"

  objcopy_embed_flag: "-I"
  objcopy_embed_flag: "binary"

  compiler_flag: "-B%{toolchain_path_prefix}bin"
  tool_path {name: "ld" path: "/usr/bin/ld" }  # lld is not ready for macOS.
  tool_path {name: "cpp" path: "%{tools_path_prefix}bin/clang-cpp" }
  tool_path {name: "dwp" path: "%{tools_path_prefix}bin/llvm-dwp" }
  tool_path {name: "gcov" path: "%{tools_path_prefix}bin/llvm-profdata" }
  tool_path {name: "nm" path: "%{tools_path_prefix}bin/llvm-nm" }
  tool_path {name: "objcopy" path: "%{tools_path_prefix}bin/llvm-objcopy" }
  tool_path {name: "objdump" path: "%{tools_path_prefix}bin/llvm-objdump" }
  tool_path {name: "strip" path: "/usr/bin/strip" }
  tool_path {name: "gcc" path: "%{tools_path_prefix}cc_wrapper.sh" }
  tool_path {name: "ar" path: "%{tools_path_prefix}bin/llvm-ar" }

  compilation_mode_flags {
    mode: FASTBUILD
    compiler_flag: "-O0"
    compiler_flag: "-DDEBUG"
  }

  compilation_mode_flags {
    mode: OPT
    compiler_flag: "-g0"
    compiler_flag: "-O2"
    compiler_flag: "-D_FORTIFY_SOURCE=1"
    compiler_flag: "-DNDEBUG"
    compiler_flag: "-ffunction-sections"
    compiler_flag: "-fdata-sections"
  }

  compilation_mode_flags {
    mode: DBG
    compiler_flag: "-g"
  }

  linking_mode_flags {
    mode: DYNAMIC
    linker_flag: "-undefined"
    linker_flag: "dynamic_lookup"
  }

  make_variable {
    name: "STACK_FRAME_UNLIMITED"
    value: "-Wframe-larger-than=100000000 -Wno-vla"
  }

  linking_mode_flags { mode: DYNAMIC }

  feature {
    name: "framework_paths"
    flag_set {
      action: "objc-compile"
      action: "objc++-compile"
      action: "objc-executable"
      action: "objc++-executable"
      flag_group {
        flag: "-F%{framework_paths}"
        iterate_over: "framework_paths"
      }
    }
  }
  
  feature {
    name: "coverage"
  }
  feature {
    name: "llvm_coverage_map_format"
    flag_set {
      action: "preprocess-assemble"
      action: "c-compile"
      action: "c++-compile"
      action: "c++-module-compile"
      action: "objc-compile"
      action: "objc++-compile"
      flag_group {
        flag: "-fprofile-instr-generate"
        flag: "-fcoverage-mapping"
        flag: "-g"
      }
    }
    flag_set {
      action: "c++-link-dynamic-library"
      action: "c++-link-nodeps-dynamic-library"
      action: "c++-link-executable"
      action: "objc-executable"
      action: "objc++-executable"
      flag_group {
        flag: "-fprofile-instr-generate"
      }
    }
    requires {
      feature: "coverage"
    }
  }
  feature {
    name: "gcc_coverage_map_format"
    flag_set {
      action: "preprocess-assemble"
      action: "c-compile"
      action: "c++-compile"
      action: "c++-module-compile"
      action: "objc-compile"
      action: "objc++-compile"
      flag_group {
        flag: "-fprofile-arcs"
        flag: "-ftest-coverage"
        flag: "-g"
      }
    }
    flag_set {
      action: "c++-link-dynamic-library"
      action: "c++-link-nodeps-dynamic-library"
      action: "c++-link-executable"
      flag_group {
        flag: "-lgcov"
      }
    }
    requires {
      feature: "coverage"
    }
  }
}
