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
            urls = ["https://github.com/bazelbuild/rules_cc/releases/download/0.2.27/rules_cc-0.2.27.tar.gz"],
            sha256 = "6bcf1b46d9e629cbe4c96d7bfc56f61034c2193b7b16001201282ea50bef5d91",
            strip_prefix = "rules_cc-0.2.27",
        )

    # rules_cc's cc_toolchain_config rule depends on apple_support's Xcode
    # configuration, including for non-Apple toolchains.
    if not native.existing_rule("apple_support"):
        http_archive(
            name = "apple_support",
            sha256 = "447506cead9e3a2c382b4780f4fab8dbb8f6c3f7df309a7914247262c5f51e00",
            urls = ["https://github.com/bazelbuild/apple_support/releases/download/2.11.0/apple_support.2.11.0.tar.gz"],
        )

    # Load bazel_skylib if the user has not defined them.
    if not native.existing_rule("bazel_skylib"):
        http_archive(
            name = "bazel_skylib",
            urls = [
                "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.9.2/bazel-skylib-1.9.2.tar.gz",
                "https://github.com/bazelbuild/bazel-skylib/releases/download/1.9.2/bazel-skylib-1.9.2.tar.gz",
            ],
            sha256 = "37cdfbc6faefea94f7b37760a305c98c08981116c2bc9e821e3b423221fad8c8",
        )

    # Load bazel_features if the user has not defined them.
    if not native.existing_rule("bazel_features"):
        http_archive(
            name = "bazel_features",
            sha256 = "99232c34de353633c384188afa372d86a9dedbd19c4b46f99ac88a1ff11bb299",
            strip_prefix = "bazel_features-1.53.0",
            url = "https://github.com/bazel-contrib/bazel_features/releases/download/v1.53.0/bazel_features-v1.53.0.tar.gz",
        )

    if not native.existing_rule("mboworks_bzl"):
        http_archive(
            name = "mboworks_bzl",
            url = "https://github.com/mboworks/bzl/releases/download/0.8.0/bzl-0.8.0.tar.gz",
            sha256 = "1a1494423bd40de09f01d9a06fd6f811d49a3a095970bfae82c9280191ab5f90",
            strip_prefix = "bzl-0.8.0",
        )
