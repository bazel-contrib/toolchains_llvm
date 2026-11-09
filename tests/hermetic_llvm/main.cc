#if !defined(__clang__) || __clang_major__ != 23
#error                                                                         \
    "This test must use the selected LLVM 23 distribution, not a fallback compiler"
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
