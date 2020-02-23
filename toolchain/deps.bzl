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
            sha256 = "b6f34b3261ec02f85dbc5a8bdc9414ce548e1f5f67e000d7069571799cb88b25",
            strip_prefix = "rules_cc-726dd8157557f1456b3656e26ab21a1646653405",
            urls = ["https://github.com/bazelbuild/rules_cc/archive/726dd8157557f1456b3656e26ab21a1646653405.tar.gz"],
        )
