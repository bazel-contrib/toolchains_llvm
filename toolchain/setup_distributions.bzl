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

"""Public seam for materializing the merged LLVM distribution table.

WORKSPACE-mode consumers (including this repository's own root WORKSPACE)
load this file and call `setup_llvm_distributions()` to register the
`@llvm_distributions_data` repo. In bzlmod the same repo is registered by
the `llvm_distributions` module extension declared in MODULE.bazel.

Kept under `//toolchain/` (not `//toolchain/internal/`) so external WORKSPACE
files can load it without tripping buildifier's `bzl-visibility` lint; the
underlying `llvm_distributions_repo` rule itself stays internal.
"""

load("//toolchain/internal:distributions_repo.bzl", "llvm_distributions_repo")

def setup_llvm_distributions():
    """Register `@llvm_distributions_data` if it has not already been registered."""
    if native.existing_rule("llvm_distributions_data"):
        return
    llvm_distributions_repo(
        name = "llvm_distributions_data",
        # Order matters: later entries override earlier ones on key
        # collisions, which lets `extra.jsonc` pin SHA-256s for any tarball
        # in the other three files. Do not let buildifier reorder.
        srcs = [
            # do not sort
            "@toolchains_llvm//toolchain/distributions:pre_github.jsonc",
            "@toolchains_llvm//toolchain/distributions:github_legacy.jsonc",
            "@toolchains_llvm//toolchain/distributions:github.jsonc",
            "@toolchains_llvm//toolchain/distributions:extra.jsonc",
        ],
    )
