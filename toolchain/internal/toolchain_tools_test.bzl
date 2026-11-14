# Copyright 2026 The Bazel Authors.
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

"""Tests for tool inputs from full and slim LLVM distributions."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(":common.bzl", "toolchain_tools")

def _present_tool(_name):
    return struct(exists = True)

def _missing_tool(_name):
    return struct(exists = False)

def _coverage_tool(name):
    return struct(exists = name in ["llvm-cov", "llvm-profdata"])

def _full_distribution_test_impl(ctx):
    env = unittest.begin(ctx)
    for os in ["linux", "darwin"]:
        asserts.equals(
            env,
            toolchain_tools(os),
            toolchain_tools(os, struct(get_child = _present_tool)),
        )
    return unittest.end(env)

def _slim_distribution_test_impl(ctx):
    env = unittest.begin(ctx)
    required_tools = {
        "clang-cpp": "clang-cpp",
        "ld.lld": "ld.lld",
        "llvm-ar": "llvm-ar",
        "llvm-nm": "llvm-nm",
        "llvm-objcopy": "llvm-objcopy",
        "llvm-objdump": "llvm-objdump",
        "llvm-strip": "llvm-strip",
    }

    # Even missing required tools must remain declared inputs; only optional
    # tools may be removed. Darwin's required libtool alias must also survive.
    asserts.equals(env, required_tools, toolchain_tools("linux", struct(get_child = _missing_tool)))
    asserts.equals(
        env,
        dict(required_tools, **{"llvm-libtool-darwin": "libtool"}),
        toolchain_tools("darwin", struct(get_child = _missing_tool)),
    )
    return unittest.end(env)

def _partial_distribution_test_impl(ctx):
    env = unittest.begin(ctx)
    tools = toolchain_tools("linux", struct(get_child = _coverage_tool))
    expected = toolchain_tools("linux")
    for name in ["clang-format", "clang-tidy", "clangd", "llvm-dwp"]:
        expected.pop(name)
    asserts.equals(env, expected, tools)
    return unittest.end(env)

_full_distribution_test = unittest.make(_full_distribution_test_impl)
_slim_distribution_test = unittest.make(_slim_distribution_test_impl)
_partial_distribution_test = unittest.make(_partial_distribution_test_impl)

def toolchain_tools_test_suite(name):
    unittest.suite(
        name,
        _full_distribution_test,
        _slim_distribution_test,
        _partial_distribution_test,
    )
