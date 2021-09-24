// Copyright 2021 The Bazel Authors.
//
// Licensed under the Apache License, Version 2.0(the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http:  // www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#if defined(__linux__) && defined(_GNU_SOURCE)
#include <dlfcn.h>
#include <assert.h>

// Checks that pthread symbols are loadable.
//
// This test verifies that dynamically linked libraries which
// rely on pthread symbols can still access them.
// Incorrect order of linking dependencies may remove unused
// symbols and break shared libraries that are linked later.
int main() {
   // Find symbol
   void* symbol = dlsym(RTLD_NEXT, "pthread_getspecific");
   // Check that there is no error
   assert(dlerror() == nullptr && symbol != nullptr);

}

#else//defined(__linux__) && defined(_GNU_SOURCE)

int main() {
}

#endif//defined(__linux__) && defined(_GNU_SOURCE)
