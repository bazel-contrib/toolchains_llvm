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

"""Regression tests for supported_platforms configuration and validation."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts", "unittest")
load(":common.bzl", "platform_is_supported")

def _context(platforms, host_os = "linux", host_arch = "amd64", exec_os = "", exec_arch = ""):
    return struct(
        attr = struct(
            supported_platforms = platforms,
            exec_os = exec_os,
            exec_arch = exec_arch,
        ),
        os = struct(name = host_os, arch = host_arch),
    )

def _os_entries_test_impl(ctx):
    env = unittest.begin(ctx)
    for host_os, entry, arches in [
        ("linux", "linux", ["amd64", "x86_64", "arm64", "aarch64", "riscv64"]),
        ("mac os x", "darwin", ["amd64", "x86_64", "arm64", "aarch64"]),
    ]:
        for arch in arches:
            asserts.true(env, platform_is_supported(_context([entry], host_os, arch)), "{} {}".format(host_os, arch))
    asserts.false(env, platform_is_supported(_context(["linux"], "mac os x")))
    asserts.false(env, platform_is_supported(_context(["darwin"], "linux")))
    return unittest.end(env)

def _exact_platform_test_impl(ctx):
    env = unittest.begin(ctx)
    for entry, host_os, arch, expected in [
        ("linux-x86_64", "linux", "amd64", True),
        ("linux-x86_64", "linux", "x86_64", True),
        ("linux-x86_64", "linux", "arm64", False),
        ("linux-aarch64", "linux", "arm64", True),
        ("linux-aarch64", "linux", "aarch64", True),
        ("linux-aarch64", "linux", "amd64", False),
        ("darwin-aarch64", "mac os x", "arm64", True),
        ("darwin-aarch64", "mac os x", "aarch64", True),
        ("darwin-aarch64", "mac os x", "amd64", False),
        ("darwin-aarch64", "linux", "aarch64", False),
        ("darwin-x86_64", "mac os x", "amd64", True),
        ("darwin-x86_64", "mac os x", "arm64", False),
    ]:
        asserts.equals(env, expected, platform_is_supported(_context([entry], host_os, arch)), "{} on {} {}".format(entry, host_os, arch))
    return unittest.end(env)

def _readme_example_test_impl(ctx):
    env = unittest.begin(ctx)

    # Keep the documented mixed OS / OS-architecture allowlist working.
    platforms = ["linux", "darwin-aarch64"]
    for host_os, arch, expected in [
        ("linux", "amd64", True),
        ("linux", "arm64", True),
        ("linux", "riscv64", True),
        ("mac os x", "arm64", True),
        ("mac os x", "amd64", False),
        ("openbsd", "amd64", False),
        ("windows", "amd64", False),
    ]:
        asserts.equals(env, expected, platform_is_supported(_context(platforms, host_os, arch)), "{} {}".format(host_os, arch))
    return unittest.end(env)

def _defaults_test_impl(ctx):
    env = unittest.begin(ctx)
    for host_os in ["linux", "mac os x"]:
        for arch in ["amd64", "arm64"]:
            asserts.true(env, platform_is_supported(_context([], host_os, arch)))

    # Preserve the pre-existing Windows bypass even without an allowlist.
    for host_os in ["windows", "windows 10"]:
        asserts.false(env, platform_is_supported(_context([], host_os)))
    return unittest.end(env)

def _exec_overrides_test_impl(ctx):
    env = unittest.begin(ctx)
    for arch in ["amd64", "x86_64"]:
        remote = _context(["linux-x86_64"], "mac os x", "arm64", exec_os = "linux", exec_arch = arch)
        asserts.true(env, platform_is_supported(remote))
    for arch in ["arm64", "aarch64"]:
        remote = _context(["darwin-aarch64"], "linux", "amd64", exec_os = "darwin", exec_arch = arch)
        asserts.true(env, platform_is_supported(remote))

    # Each override takes precedence independently, and matching uses the
    # execution platform even if the host itself would match the allowlist.
    asserts.true(env, platform_is_supported(_context(["linux-x86_64"], "mac os x", "amd64", exec_os = "linux")))
    asserts.true(env, platform_is_supported(_context(["darwin-aarch64"], "mac os x", "amd64", exec_arch = "arm64")))
    asserts.false(env, platform_is_supported(_context(["darwin-aarch64"], "mac os x", "arm64", exec_os = "linux")))
    asserts.true(env, platform_is_supported(_context(["linux"], "openbsd", exec_os = "linux")))
    return unittest.end(env)

def _invalid_platform_impl(ctx):
    platform_is_supported(_context(ctx.attr.platforms, host_os = ctx.attr.host_os))
    return []

_invalid_platform = rule(
    implementation = _invalid_platform_impl,
    attrs = {
        "platforms": attr.string_list(),
        "host_os": attr.string(default = "linux"),
    },
)

def _invalid_platform_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, ctx.attr.message)
    return analysistest.end(env)

_invalid_platform_test = analysistest.make(_invalid_platform_test_impl, expect_failure = True, attrs = {"message": attr.string()})
_os_entries_test = unittest.make(_os_entries_test_impl)
_exact_platform_test = unittest.make(_exact_platform_test_impl)
_readme_example_test = unittest.make(_readme_example_test_impl)
_defaults_test = unittest.make(_defaults_test_impl)
_exec_overrides_test = unittest.make(_exec_overrides_test_impl)

def supported_platforms_test_suite(name):
    """Test documented matching, platform exclusions, overrides and errors."""
    tests = []
    for case, invalid_entry in {
        "prefix": "lin",
        "wildcard": "linux-*",
        "arch_alias": "darwin-arm64",
        "distribution_key": "ubuntu-22.04-x86_64",
    }.items():
        subject = name + "_" + case + "_subject"
        test = name + "_" + case + "_test"

        # Invalid entries must fail even when another entry matches the host.
        _invalid_platform(name = subject, platforms = ["linux", invalid_entry], tags = ["manual"])
        _invalid_platform_test(name = test, target_under_test = subject, message = "key: " + invalid_entry + ";")
        tests.append(test)

    subject = name + "_unknown_os_subject"
    test = name + "_unknown_os_test"
    _invalid_platform(name = subject, host_os = "openbsd", tags = ["manual"])
    _invalid_platform_test(name = test, target_under_test = subject, message = "Unsupported OS: openbsd")
    tests.append(test)

    for suffix, test_rule in {
        "os_entries": _os_entries_test,
        "exact_platform": _exact_platform_test,
        "readme_example": _readme_example_test,
        "defaults": _defaults_test,
        "exec_overrides": _exec_overrides_test,
    }.items():
        test = name + "_" + suffix + "_test"
        test_rule(name = test)
        tests.append(test)
    native.test_suite(name = name, tests = tests)
