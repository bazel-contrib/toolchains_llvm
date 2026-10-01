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

"""Ensure macOS ThinLTO is enabled, rather than silently ignored."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _flags_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)
    compiles = [a for a in actions if a.mnemonic == "CppCompile"]
    links = [a for a in actions if a.mnemonic == "CppLink"]
    asserts.equals(env, 1, len(compiles), "expected one C/C++ compile action")
    if ctx.attr.expect_link:
        asserts.equals(env, 1, len(links), "expected a link action")
    for action in compiles + links:
        asserts.equals(env, ctx.attr.enabled, "-flto=thin" in action.argv, "incorrect ThinLTO flags: %s" % action.argv)
        asserts.false(env, any(["thinlto-index" in arg or "thinlto-emit-imports" in arg for arg in action.argv]), "Darwin must use linker-managed ThinLTO")
    asserts.false(env, any([a.mnemonic in ["CppLTOIndexing", "LtoBackend"] for a in actions]), "Darwin must not schedule ELF-style distributed ThinLTO")
    return analysistest.end(env)

_attrs = {"enabled": attr.bool(default = True), "expect_link": attr.bool()}
_enabled_test = analysistest.make(_flags_test_impl, attrs = _attrs, config_settings = {"//command_line_option:features": ["thin_lto"]})
_disabled_test = analysistest.make(_flags_test_impl, attrs = _attrs, config_settings = {"//command_line_option:features": ["thin_lto", "-thin_lto"]})
_default_test = analysistest.make(_flags_test_impl, attrs = _attrs, config_settings = {"//command_line_option:features": []})

def thin_lto_flags_tests(name):
    """Check C/C++ compilation, linking, and explicit/default disablement."""
    tests = []
    for target in ["c_part", "cpp_part", "thin_lto_test"]:
        test_name = name + "_" + target
        _enabled_test(name = test_name, target_under_test = ":" + target, expect_link = target == "thin_lto_test", target_compatible_with = ["@platforms//os:macos"])
        tests.append(test_name)
    for suffix, rule in [("disabled", _disabled_test), ("default", _default_test)]:
        test_name = name + "_" + suffix
        rule(name = test_name, target_under_test = ":thin_lto_test", enabled = False, expect_link = True, target_compatible_with = ["@platforms//os:macos"])
        tests.append(test_name)
    native.test_suite(name = name, tests = tests)
