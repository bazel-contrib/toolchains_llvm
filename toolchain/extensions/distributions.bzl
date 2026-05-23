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

"""Module extension that materializes `@llvm_distributions_data//:data.bzl`.

The generated data.bzl exports the merged `LLVM_DISTRIBUTIONS` and
`LLVM_DISTRIBUTION_URLS` maps consumed by
`//toolchain/internal:llvm_distributions.bzl`. Source JSONC files are listed
explicitly below so Bazel knows to re-run the rule when any of them changes.
Adding a new bundled distribution file = drop the JSONC in
`//toolchain/distributions/` and add one entry to the `srcs` list here.
"""

load("//toolchain/internal:distributions_repo.bzl", "llvm_distributions_repo")

def _impl(_module_ctx):
    llvm_distributions_repo(
        name = "llvm_distributions_data",
        srcs = [
            "//toolchain/distributions:pre_github.jsonc",
            "//toolchain/distributions:github_legacy.jsonc",
            "//toolchain/distributions:github.jsonc",
            "//toolchain/distributions:extra.jsonc",
        ],
    )

llvm_distributions = module_extension(implementation = _impl)
