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

"""Regression tests for Bazel-dependent LLVM archive selection."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@llvm_distributions_data//:data.bzl", "LLVM_DISTRIBUTIONS")
load(":llvm_distributions.bzl", _testing = "testing")

def _host(os = "linux", arch = "x86_64"):
    return struct(os = os, arch = arch, dist = struct(name = "ubuntu" if os == "linux" else os, version = "24.04" if os == "linux" else ""))

def _catalogue(basenames):
    return _testing.get_all_llvm_distributions(
        llvm_distributions = {},
        extra_llvm_distributions = {basename: "1" * 64 for basename in basenames},
        parsed_llvm_version = None,
    )

def _version_gate_test_impl(ctx):
    env = unittest.begin(ctx)
    for version in ["", "development", "7.7.2", "8.8.2", "8.99.0", "9.0.0", "9.2.0", "9.2.99", "9.3.0rc1", "9.3.0rc1 abc123", "10.0.0-pre.20260916.5"]:
        asserts.equals(env, [".tar.xz", ".tar.gz"], _testing.llvm_archive_suffixes(version), version)
    for version in ["9.3.0", "9.3.0 abc123", "9.3.1rc1", "9.3.2", "9.10.0", "10.0.0-pre.20261001.2", "10.0.0-pre.20261006.3", "10.0.0rc1", "10.0.0", "11.0.0"]:
        asserts.equals(env, [".tar.zst", ".tar.xz", ".tar.gz"], _testing.llvm_archive_suffixes(version), version)
    return unittest.end(env)

def _platforms_test_impl(ctx):
    env = unittest.begin(ctx)
    for os, arch, stem in [
        ("linux", "x86_64", "LLVM-23.1.2-Linux-X64"),
        ("linux", "aarch64", "LLVM-23.1.2-Linux-ARM64"),
        ("darwin", "x86_64", "LLVM-23.1.2-macOS-X64"),
        ("darwin", "aarch64", "LLVM-23.1.2-macOS-ARM64"),
        ("windows", "x86_64", "clang+llvm-23.1.2-x86_64-pc-windows-msvc"),
        ("windows", "aarch64", "clang+llvm-23.1.2-aarch64-pc-windows-msvc"),
    ]:
        # Insert the preferred archive last: preference is not dict ordering.
        available = _catalogue([stem + suffix for suffix in [".tar.gz", ".tar.xz", ".tar.zst"]])
        for version, suffix in [("7.7.2", ".tar.xz"), ("8.8.2", ".tar.xz"), ("9.2.0", ".tar.xz"), ("9.3.0", ".tar.zst")]:
            basename, error = _testing.find_llvm_basename_or_error("23.1.2", available, _host(os, arch), bazel_version = version)
            asserts.equals(env, None, error)
            asserts.equals(env, stem + suffix, basename)

    return unittest.end(env)

def _fallbacks_test_impl(ctx):
    env = unittest.begin(ctx)
    for stem in ["LLVM-23.1.2-Linux-X64", "clang+llvm-23.1.2-x86_64-linux-gnu-ubuntu-24.04"]:
        for version in ["9.2.0", "9.3.0"]:
            for suffixes, expected in [
                ([".tar.gz", ".tar.xz"], ".tar.xz"),
                ([".tar.gz"], ".tar.gz"),
                ([".tar.zst"], ".tar.zst" if version == "9.3.0" else None),
            ]:
                available = _catalogue([stem + suffix for suffix in suffixes])
                basename, error = _testing.find_llvm_basename_or_error("23.1.2", available, _host(), bazel_version = version)
                if expected:
                    asserts.equals(env, None, error)
                    asserts.equals(env, stem + expected, basename)
                else:
                    asserts.equals(env, None, basename)
                    asserts.true(env, error.startswith("ERROR: No matching config"))
    return unittest.end(env)

def _prefix_matching_test_impl(ctx):
    env = unittest.begin(ctx)
    for os, arch, stem in [
        ("darwin", "aarch64", "clang+llvm-23.1.2-arm64-apple-darwin22.0"),
        ("linux", "aarch64", "clang+llvm-23.1.2-aarch64-linux-gnu-ubuntu-22.04"),
        ("linux", "x86_64", "clang+llvm-23.1.2-x86_64-linux-gnu-ubuntu-22.04"),
    ]:
        available = _catalogue([stem + suffix for suffix in [".tar.xz", ".tar.zst", ".tar.gz"]])
        for version, suffix in [("9.2.0", ".tar.xz"), ("9.3.0", ".tar.zst")]:
            basename, error = _testing.find_llvm_basename_or_error("23.1.2", available, _host(os, arch), bazel_version = version)
            asserts.equals(env, None, error)
            asserts.equals(env, stem + suffix, basename)

    # Compression alternatives must not hide genuinely ambiguous platforms.
    available = _catalogue([
        "clang+llvm-23.1.2-arm64-apple-darwin{}{}".format(release, suffix)
        for release in ["22.0", "23.0"]
        for suffix in [".tar.xz", ".tar.zst"]
    ])
    for version in ["9.2.0", "9.3.0"]:
        basename, error = _testing.find_llvm_basename_or_error("23.1.2", available, _host("darwin", "aarch64"), bazel_version = version)
        asserts.equals(env, None, basename)
        asserts.true(env, error.startswith("ERROR: Multiple configurations"))

    # Prefer the matching distribution before considering compression of a
    # less suitable platform archive.
    available = _catalogue([
        "clang+llvm-23.1.2-x86_64-linux-gnu-ubuntu-24.04.tar.xz",
        "clang+llvm-23.1.2-x86_64-linux-gnu-ubuntu-22.04.tar.zst",
    ])
    basename, error = _testing.find_llvm_basename_or_error("23.1.2", available, _host(), bazel_version = "9.3.0")
    asserts.equals(env, None, error)
    asserts.equals(env, "clang+llvm-23.1.2-x86_64-linux-gnu-ubuntu-24.04.tar.xz", basename)
    return unittest.end(env)

def _version_selectors_test_impl(ctx):
    env = unittest.begin(ctx)
    available = _catalogue([
        "LLVM-23.1.2-Linux-X64.tar.xz",
        "LLVM-23.1.2-Linux-X64.tar.zst",
        "LLVM-23.1.3-Linux-X64.tar.zst",
    ])
    for bazel_version, expected_version, suffix in [("9.2.0", "23.1.2", ".tar.xz"), ("9.3.0", "23.1.3", ".tar.zst")]:
        for selector in ["latest", "latest:>=23.1.2,<24"]:
            version, basename, error = _testing.required_llvm_release_name(
                version_or_requirements = selector,
                all_llvm_distributions = available,
                host_info = _host(),
                bazel_version = bazel_version,
            )
            asserts.equals(env, None, error)
            asserts.equals(env, expected_version, version)
            asserts.equals(env, "LLVM-{}-Linux-X64{}".format(version, suffix), basename)

    # Version preference takes precedence over archive format preference.
    available = _catalogue(["LLVM-23.1.2-Linux-X64.tar.zst", "LLVM-23.1.3-Linux-X64.tar.xz"])
    version, basename, error = _testing.required_llvm_release_name(version_or_requirements = "latest", all_llvm_distributions = available, host_info = _host(), bazel_version = "9.3.0")
    asserts.equals(env, None, error)
    asserts.equals(env, "23.1.3", version)
    asserts.equals(env, "LLVM-23.1.3-Linux-X64.tar.xz", basename)
    return unittest.end(env)

def _published_archives_test_impl(ctx):
    env = unittest.begin(ctx)
    for os, arch, stem in [
        ("linux", "x86_64", "LLVM-23.1.2-Linux-X64"),
        ("linux", "aarch64", "LLVM-23.1.2-Linux-ARM64"),
        ("darwin", "aarch64", "LLVM-23.1.2-macOS-ARM64"),
    ]:
        for version, suffix in [("9.2.0", ".tar.xz"), ("9.3.0", ".tar.zst")]:
            basename, error = _testing.find_llvm_basename_or_error("23.1.2", LLVM_DISTRIBUTIONS, _host(os, arch), bazel_version = version)
            asserts.equals(env, None, error)
            asserts.equals(env, stem + suffix, basename)
    return unittest.end(env)

_version_gate_test = unittest.make(_version_gate_test_impl)
_platforms_test = unittest.make(_platforms_test_impl)
_fallbacks_test = unittest.make(_fallbacks_test_impl)
_prefix_matching_test = unittest.make(_prefix_matching_test_impl)
_version_selectors_test = unittest.make(_version_selectors_test_impl)
_published_archives_test = unittest.make(_published_archives_test_impl)

def archive_selection_test_suite(name):
    """Test the version gate, platform matching, fallbacks and real catalogue."""
    tests = []
    for suffix, test_rule in {
        "version_gate": _version_gate_test,
        "platforms": _platforms_test,
        "fallbacks": _fallbacks_test,
        "prefix_matching": _prefix_matching_test,
        "version_selectors": _version_selectors_test,
        "published_archives": _published_archives_test,
    }.items():
        test = name + "_" + suffix + "_test"
        test_rule(name = test)
        tests.append(test)
    native.test_suite(name = name, tests = tests)
