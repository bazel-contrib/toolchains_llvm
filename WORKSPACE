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
    sha256 = "3f1c99c6cf231691000f840acad0a45c7a7a6f6e3e126df96173e279ce2fcce5",
    strip_prefix = "bzl-0.3.0",
    url = "https://github.com/helly25/bzl/releases/download/0.3.0/bzl-0.3.0.tar.gz",
)
