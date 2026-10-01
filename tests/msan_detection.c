// Copyright 2026 The Bazel Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Prove that a C compilation and the linked MSan runtime detect poisoned data.
// Poison an initialized value explicitly so optimization cannot turn an
// undefined C read into a constant or remove the test altogether.
#if !__has_feature(memory_sanitizer)
#error "THIS TEST REQUIRES MEMORYSANITIZER INSTRUMENTATION"
#endif

#include <sanitizer/msan_interface.h>

int main(void) {
  volatile int value = 42;
  __msan_poison((void *)&value, sizeof(value));
  return value;
}
