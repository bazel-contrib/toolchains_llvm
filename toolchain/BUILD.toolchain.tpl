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

package(default_visibility = ["//visibility:public"])

load("@rules_cc//cc:defs.bzl", "cc_toolchain", "cc_toolchain_suite")
load("%{cc_toolchain_config_bzl}", "cc_toolchain_config")

exports_files(["Makevars"])

# Needed for old style --cpu and --compiler command line flags when using
# crosstool_top.
# TODO: Delete this and rely on toolchain registration mechanism alone.
cc_toolchain_suite(
    name = "toolchain",
    toolchains = {
        "k8|clang": ":cc-clang-x86_64-linux",
        "aarch64|clang": ":cc-clang-aarch64-linux",
        "darwin|clang": ":cc-clang-x86_64-darwin",
        "k8": ":cc-clang-x86_64-linux",
        "aarch64": ":cc-clang-aarch64-linux",
        "darwin": ":cc-clang-x86_64-darwin",
    },
)

# Following filegroup targets are used when not using absolute paths and shared
# between different toolchains.

filegroup(
    name = "empty",
    srcs = [],
)

filegroup(
    name = "cc-wrapper",
    srcs = ["bin/cc_wrapper.sh"],
)

%{cc_toolchains}
