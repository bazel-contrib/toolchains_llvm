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

workspace(
    name = "toolchains_llvm",
)

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "helly25_bzl",
    sha256 = "404f8473bcaad2e370752e57d274d2093eb87ca94cb9a597c1a3553b76743206",
    strip_prefix = "bzl-0.1.2",
    url = "https://github.com/helly25/bzl/releases/download/0.1.2/bzl-0.1.2.tar.gz",
)
