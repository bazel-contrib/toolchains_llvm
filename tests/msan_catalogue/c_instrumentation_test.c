#if !__has_feature(memory_sanitizer)
#error "THIS TEST REQUIRES C MEMORYSANITIZER INSTRUMENTATION"
#endif

#include <sanitizer/msan_interface.h>

int main(void) {
  int value = 42;
  __msan_poison(&value, sizeof(value));
  if (__msan_test_shadow(&value, sizeof(value)) != 0)
    return 1;
  __msan_unpoison(&value, sizeof(value));
  return __msan_test_shadow(&value, sizeof(value)) == -1 ? 0 : 1;
}
