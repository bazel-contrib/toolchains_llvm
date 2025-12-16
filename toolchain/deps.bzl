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

def bazel_toolchain_dependencies():
    # Load rules_cc if the user has not defined them.
    if not native.existing_rule("rules_cc"):
        http_archive(
            name = "rules_cc",
            urls = ["https://github.com/bazelbuild/rules_cc/releases/download/0.2.14/rules_cc-0.2.14.tar.gz"],
            sha256 = "a2fdfde2ab9b2176bd6a33afca14458039023edb1dd2e73e6823810809df4027",
            strip_prefix = "rules_cc-0.2.14",
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
            sha256 = "07271d0f6b12633777b69020c4cb1eb67b1939c0cf84bb3944dc85cc250c0c01",
            strip_prefix = "bazel_features-1.38.0",
            url = "https://github.com/bazel-contrib/bazel_features/releases/download/v1.38.0/bazel_features-v1.38.0.tar.gz",
        )

    # Load helly25_bzl for version comparisons.
    if not native.existing_rule("helly25_bzl"):
        http_archive(
            name = "helly25_bzl",
            strip_prefix = "bzl-0.3.1",
            url = "https://github.com/helly25/bzl/releases/download/0.3.1/bzl-0.3.1.tar.gz",
            sha256 = "c8e28a3cb7e465b4b71f5d4d366c5796cc0ae822fa510a8adf12cf39a9709902",
        )
