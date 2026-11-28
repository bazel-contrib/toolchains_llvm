#ifndef EXPECTED_LLVM_PATCHLEVEL
#define EXPECTED_LLVM_PATCHLEVEL 6
#endif
#if !defined(__clang__) || __clang_major__ != 23 || __clang_minor__ != 1 ||    \
    __clang_patchlevel__ != EXPECTED_LLVM_PATCHLEVEL
#error                                                                         \
    "This test must use the selected LLVM 23.1 patch version, not a fallback compiler"
#endif
#if defined(__linux__)
#include <bits/c++config.h>
#ifndef __GLIBCXX__
#error "The Linux hermetic-LLVM test must use libstdc++"
#endif
#endif

extern "C" int c_answer(void);
int cpp_answer();
int main() { return c_answer() == 42 && cpp_answer() == 42 ? 0 : 1; }
