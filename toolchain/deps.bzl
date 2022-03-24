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
            sha256 = "c22f7b4b87c0604f08479190fc0fb09c928982ff8f52b797263505e3b5a75f89",
            strip_prefix = "rules_cc-58f8e026c00a8a20767e3dc669f46ba23bc93bdb",
            urls = ["https://github.com/bazelbuild/rules_cc/archive/58f8e026c00a8a20767e3dc669f46ba23bc93bdb.tar.gz"],
        )
