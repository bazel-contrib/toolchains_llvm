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
    name = "mboworks_bzl",
    sha256 = "0c51edbd3a3b69ebff59b5ffec411a3ab8cb137a845b9bba9803738cd7bd5c28",
    strip_prefix = "bzl-0.5.1",
    url = "https://github.com/mboworks/bzl/releases/download/0.5.1/bzl-0.5.1.tar.gz",
)

# Materialize the merged LLVM distribution table for WORKSPACE-mode builds
# of this repo (toolchain_test in CI runs //toolchain/... with
# --enable_bzlmod=false). In bzlmod, the same repo is materialized by the
# `llvm_distributions` module extension declared in MODULE.bazel.
load("//toolchain:setup_distributions.bzl", "setup_llvm_distributions")

setup_llvm_distributions()
