// An uninstrumented libc++ leaves stringstream state poisoned to MSan.
#if !__has_feature(memory_sanitizer)
#error "THIS TEST REQUIRES MEMORYSANITIZER INSTRUMENTATION"
#endif
#if __clang_major__ != 22 || __clang_minor__ != 1 || __clang_patchlevel__ != 8
#error "THIS TEST REQUIRES THE CATALOGUED LLVM 22.1.8 COMPILER"
#endif

#include <iomanip>
#include <memory>
#include <sstream>
#include <string>

int main() {
  std::stringstream stack;
  stack << std::setprecision(5) << 3.14159;
  auto heap = std::make_unique<std::stringstream>();
  *heap << std::setprecision(7) << 3.14159;
  return stack.precision() == 5 && heap->precision() == 7 &&
                 !stack.str().empty() && !heap->str().empty()
             ? 0
             : 1;
}
