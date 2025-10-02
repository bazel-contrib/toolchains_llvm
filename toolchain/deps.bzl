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
            urls = ["https://github.com/bazelbuild/rules_cc/releases/download/0.2.2/rules_cc-0.2.2.tar.gz"],
            sha256 = "e50f24506011841e2ac83d9733a0c7e058eb3a10a6e3e10baa9c7942ff5f4767",
            strip_prefix = "rules_cc-0.2.2",
        )

    # Load bazel_skylib if the user has not defined them.
    if not native.existing_rule("bazel_skylib"):
        http_archive(
            name = "bazel_skylib",
            urls = [
                "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.8.2/bazel-skylib-1.8.2.tar.gz",
                "https://github.com/bazelbuild/bazel-skylib/releases/download/1.8.2/bazel-skylib-1.8.2.tar.gz",
            ],
            sha256 = "6e78f0e57de26801f6f564fa7c4a48dc8b36873e416257a92bbb0937eeac8446",
        )

        # Skip bazel_skylib_workspace because we are not using lib/unittest.bzl

    # Load bazel_features if the user has not defined them.
    if not native.existing_rule("bazel_features"):
        http_archive(
            name = "bazel_features",
            sha256 = "9390b391a68d3b24aef7966bce8556d28003fe3f022a5008efc7807e8acaaf1a",
            strip_prefix = "bazel_features-1.36.0",
            url = "https://github.com/bazel-contrib/bazel_features/releases/download/v1.36.0/bazel_features-v1.36.0.tar.gz",
        )
