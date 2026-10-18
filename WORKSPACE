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

# Temporary source pin; switch to the mboworks_bzl 0.8.0 release when published.
http_archive(
    name = "mboworks_bzl",
    sha256 = "a8376d069119565c5b2421df5b6857477185392e5d898555219b96339a7ae132",
    strip_prefix = "bzl-afcd7e0279f6791880750dfbccd97c047ad51e96",
    url = "https://github.com/mboworks/bzl/archive/afcd7e0279f6791880750dfbccd97c047ad51e96.tar.gz",
)

# Materialize the merged LLVM distribution table for WORKSPACE-mode builds
# of this repo (toolchain_test in CI runs //toolchain/... with
# --enable_bzlmod=false). In bzlmod, the same repo is materialized by the
# `llvm_distributions` module extension declared in MODULE.bazel.
load("//toolchain:setup_distributions.bzl", "setup_llvm_distributions")

setup_llvm_distributions()

# Used by the feature override unit and expected-analysis-failure tests.
register_toolchains("@bazel_skylib//toolchains/unittest:all")
