# Copyright 2020 The Bazel Authors.
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

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//toolchain:setup_distributions.bzl", "setup_llvm_distributions")

def bazel_toolchain_dependencies():
    # Materialize the merged LLVM distribution table. In bzlmod this is done
    # by the `llvm_distributions` module extension; in WORKSPACE mode the
    # consumer calls `bazel_toolchain_dependencies()` which dispatches here.
    setup_llvm_distributions()

    # Load rules_cc if the user has not defined them.
    if not native.existing_rule("rules_cc"):
        http_archive(
            name = "rules_cc",
            urls = ["https://github.com/bazelbuild/rules_cc/releases/download/0.2.19/rules_cc-0.2.19.tar.gz"],
            sha256 = "351248f6be41d18694d4d7c390aaebd9f865eea72a4758b2c9d782ae744c97f4",
            strip_prefix = "rules_cc-0.2.19",
        )

    # Load bazel_skylib if the user has not defined them.
    if not native.existing_rule("bazel_skylib"):
        http_archive(
            name = "bazel_skylib",
            urls = [
                "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.9.0/bazel-skylib-1.9.0.tar.gz",
                "https://github.com/bazelbuild/bazel-skylib/releases/download/1.9.0/bazel-skylib-1.9.0.tar.gz",
            ],
            sha256 = "3b5b49006181f5f8ff626ef8ddceaa95e9bb8ad294f7b5d7b11ea9f7ddaf8c59",
        )

    # Load bazel_features if the user has not defined them.
    if not native.existing_rule("bazel_features"):
        http_archive(
            name = "bazel_features",
            sha256 = "add57e2e086463075805e153c37e03bb74c4737773fc5879336733af08e6f086",
            strip_prefix = "bazel_features-1.49.0",
            url = "https://github.com/bazel-contrib/bazel_features/releases/download/v1.49.0/bazel_features-v1.49.0.tar.gz",
        )

    # Load helly25_bzl for version comparisons.
    if not native.existing_rule("helly25_bzl"):
        http_archive(
            name = "helly25_bzl",
            url = "https://github.com/helly25/bzl/releases/download/0.4.3/bzl-0.4.3.tar.gz",
            sha256 = "8846d5363ed05dfe242af692759c9b7439c1b7ce47b9720c3338e254651cbe99",
            strip_prefix = "bzl-0.4.3",
        )
