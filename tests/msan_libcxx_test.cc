// End-to-end MemorySanitizer test.
//
// This reproduces the use-of-uninitialized-value that MSan reports when the
// linked libc++ is NOT itself instrumented (for example when the toolchain
// links the base libc++.a instead of the msan-instrumented overlay): a
// std::stringstream's internal precision field is left "uninitialized" from
// MSan's point of view, so reading it back -- or branching on a value that
// flowed through the stream -- is reported as use-of-uninitialized-value.
//
// Built and run with the msan toolchain (instrumented libc++ overlay) and
// --features=msan by tests/scripts/run_msan_tests.sh. With a correctly
// instrumented libc++ the program exits 0; otherwise MSan aborts and the test
// fails.

#include <cstdio>
#include <iomanip>
#include <limits>
#include <memory>
#include <sstream>
#include <string>

static std::string Format(double value) {
  std::stringstream ss;
  ss << std::setprecision(std::numeric_limits<double>::digits10 + 2);
  ss << value;
  return ss.str();
}

int main() {
  // Stack-allocated stream.
  std::stringstream stack_ss;
  stack_ss << std::setprecision(5);
  const std::streamsize stack_precision = stack_ss.precision();

  // Heap-allocated stream (mirrors googletest's Message, which is where this
  // was originally observed).
  auto heap_ss = std::make_unique<std::stringstream>();
  *heap_ss << std::setprecision(7);
  const std::streamsize heap_precision = heap_ss->precision();

  const std::string formatted = Format(3.14159);

  std::printf("stack=%d heap=%d formatted=%s\n",
              static_cast<int>(stack_precision),
              static_cast<int>(heap_precision), formatted.c_str());

  // Branch on values that flowed through libc++; MSan reports here if any of
  // them are (incorrectly) considered uninitialized.
  if (stack_precision != 5 || heap_precision != 7 || formatted.empty()) {
    return 1;
  }
  return 0;
}
