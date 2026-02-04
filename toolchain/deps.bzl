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
            urls = ["https://github.com/bazelbuild/rules_cc/releases/download/0.2.16/rules_cc-0.2.16.tar.gz"],
            sha256 = "458b658277ba51b4730ea7a2020efdf1c6dcadf7d30de72e37f4308277fa8c01",
            strip_prefix = "rules_cc-0.2.16",
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
            sha256 = "966c211ec42c4deb2af4c6dd6948408100b752f61753c97055bdac9bfb5cc0c7",
            strip_prefix = "bazel_features-1.41.0",
            url = "https://github.com/bazel-contrib/bazel_features/releases/download/v1.41.0/bazel_features-v1.41.0.tar.gz",
        )

    # Load helly25_bzl for version comparisons.
    if not native.existing_rule("helly25_bzl"):
        http_archive(
            name = "helly25_bzl",
            strip_prefix = "bzl-0.3.1",
            url = "https://github.com/helly25/bzl/releases/download/0.3.1/bzl-0.3.1.tar.gz",
            sha256 = "c8e28a3cb7e465b4b71f5d4d366c5796cc0ae822fa510a8adf12cf39a9709902",
        )
