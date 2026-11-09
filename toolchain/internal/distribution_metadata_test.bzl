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

"""Catalogue profiles, host selection, and incompatible configuration tests."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts", "unittest")
load(":distribution_metadata.bzl", "catalogue_metadata", "check_distribution_requirements", "distribution_requirements")
load(":distributions_repo.bzl", "archive_version", "load_distribution_files")
load(":llvm_distributions.bzl", "testing")

_ARCHIVE = "llvm-toolchain-minimal-23.1.2-linux-amd64-musl.tar.zst"
_META = {
    "strip_prefix": "",
    "platforms": {"linux-x86_64": "llvm-toolchain-minimal-{version}-linux-amd64-musl.tar.zst"},
    "requirements": {"features": ["-asan"], "stdlib": {"linux-x86_64": ["stdc++", "dynamic-stdc++"]}},
}

def _metadata_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, {}, catalogue_metadata({}, "LLVM-23.1.2-Linux-X64.tar.xz", "23.1.2"))
    metadata = catalogue_metadata(_META, _ARCHIVE, "23.1.2")
    asserts.equals(env, ["linux-x86_64"], metadata["platforms"])
    asserts.equals(env, "", metadata["strip_prefix"])
    asserts.equals(env, _META["requirements"], metadata["requirements"])
    for archive, version in [(_ARCHIVE, "23.1.2"), ("clang+llvm-23.1.0-rc2-linux.tar.xz", "23.1.0-rc2"), ("LLVM-16.0.6-Linux.tar.xz", "16.0.6")]:
        asserts.equals(env, version, archive_version(archive))
    return unittest.end(env)

def _read_file(path):
    if path == "first":
        return json.encode(dict({_ARCHIVE: "old"}, _meta = dict(_META, base_url = {"": "https://example.test/{version}/"})))
    return json.encode({_ARCHIVE: "new"})

def _merge_test_impl(ctx):
    env = unittest.begin(ctx)
    rctx = struct(path = lambda label: label, read = _read_file)
    entries, urls, metadata = load_distribution_files(rctx, ["first", "second"], with_metadata = True)
    asserts.equals(env, "new", entries[_ARCHIVE])
    asserts.equals(env, "https://example.test/23.1.2/" + _ARCHIVE, urls[_ARCHIVE])
    asserts.equals(env, _META["requirements"], metadata[_ARCHIVE]["requirements"])
    asserts.equals(env, "", metadata[_ARCHIVE]["strip_prefix"])
    return unittest.end(env)

def _selection_test_impl(ctx):
    env = unittest.begin(ctx)
    entries = testing.get_all_llvm_distributions(
        llvm_distributions = {},
        extra_llvm_distributions = {_ARCHIVE: "sha"},
        parsed_llvm_version = None,
        metadata = {_ARCHIVE: catalogue_metadata(_META, _ARCHIVE, "23.1.2")},
    )
    for os, arch, expected in [("linux", "x86_64", [_ARCHIVE]), ("linux", "aarch64", []), ("darwin", "x86_64", [])]:
        host = struct(os = os, arch = arch, dist = struct(name = os, version = ""))
        asserts.equals(env, expected, testing.find_llvm_basename_list("23.1.2", entries, host))
        version, name, error = testing.required_llvm_release_name(version_or_requirements = "latest:major==23", all_llvm_distributions = entries, host_info = host)
        if expected:
            asserts.equals(env, "23.1.2", version)
            asserts.equals(env, _ARCHIVE, name)
            asserts.equals(env, None, error)
        else:
            asserts.true(env, error != None)
    return unittest.end(env)

def _requirements_test_impl(ctx):
    env = unittest.begin(ctx)
    for stdlib in ["stdc++", "stdc++-14", "dynamic-stdc++", "dynamic-stdc++-14"]:
        check_distribution_requirements("minimal", _META["requirements"], "linux-x86_64", stdlib, [])
    check_distribution_requirements("minimal", _META["requirements"], "linux-x86_64", "stdc++", ["asan"], ["asan"])
    check_distribution_requirements("msan", {"features": ["msan"]}, "linux-x86_64", "builtin-libc++", ["msan", "unrelated"])
    return unittest.end(env)

def _failure_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, ctx.attr.message)
    return analysistest.end(env)

_failure_test = analysistest.make(_failure_test_impl, expect_failure = True, attrs = {"message": attr.string()})

def _success_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    asserts.equals(env, "compatible", target[config_common.FeatureFlagInfo].value)
    return analysistest.end(env)

_msan_enabled_test = analysistest.make(_success_test_impl, config_settings = {"//command_line_option:features": ["msan"]})
_asan_disabled_test = analysistest.make(_success_test_impl, config_settings = {"//command_line_option:features": ["asan", "-asan"]})
_msan_disabled_test = analysistest.make(_failure_test_impl, expect_failure = True, attrs = {"message": attr.string()}, config_settings = {"//command_line_option:features": ["msan", "-msan"]})

def _invalid_metadata_impl(ctx):
    catalogue_metadata(json.decode(ctx.attr.metadata), _ARCHIVE, "23.1.2")
    return []

_invalid_metadata = rule(implementation = _invalid_metadata_impl, attrs = {"metadata": attr.string()})

_metadata_test = unittest.make(_metadata_test_impl)
_merge_test = unittest.make(_merge_test_impl)
_selection_test = unittest.make(_selection_test_impl)
_requirements_test = unittest.make(_requirements_test_impl)

def distribution_metadata_test_suite(name):
    """Validate profiles without downloading LLVM, including analysis errors."""
    unittest.suite(name + "_unit", _metadata_test, _merge_test, _selection_test, _requirements_test)
    tests = [name + "_unit"]
    for case, features, test_rule in [("msan_enabled", ["msan"], _msan_enabled_test), ("asan_disabled", ["-asan"], _asan_disabled_test)]:
        subject = name + "_" + case + "_subject"
        test = name + "_" + case + "_test"
        distribution_requirements(name = subject, distribution = "test-profile", requirements = json.encode({"features": features}), target = "linux-x86_64", stdlib = "stdc++", tags = ["manual"])
        test_rule(name = test, target_under_test = subject)
        tests.append(test)
    for case, requirements, stdlib, message in [
        ("missing_msan", {"features": ["msan"]}, "builtin-libc++", "feature 'msan' must be enabled"),
        ("wrong_stdlib", _META["requirements"], "builtin-libc++", "stdlib 'builtin-libc++' is not supported"),
    ]:
        subject = name + "_" + case + "_subject"
        test = name + "_" + case + "_test"
        distribution_requirements(name = subject, distribution = "test-profile", requirements = json.encode(requirements), target = "linux-x86_64", stdlib = stdlib, tags = ["manual"])
        _failure_test(name = test, target_under_test = subject, message = message)
        tests.append(test)
        if case == "missing_msan":
            disabled_test = name + "_msan_disabled_test"
            _msan_disabled_test(name = disabled_test, target_under_test = subject, message = message)
            tests.append(disabled_test)
    for case, metadata, message in [
        ("conflicting_features", {"requirements": {"features": ["msan", "-msan"]}}, "both required and excluded"),
        ("unknown_requirement", {"requirements": {"typo": []}}, "only features and stdlib"),
        ("bad_stdlib", {"requirements": {"stdlib": {"": "stdc++"}}}, "nonempty lists"),
        ("unmatched_platform", {"platforms": {"linux-x86_64": "typo-{version}.tar.zst"}}, "do not match archive"),
        ("platform_alias", {"platforms": {"linux-arm64": _ARCHIVE}}, "unsupported catalogue execution-platform key"),
        ("stdlib_target_typo", {"requirements": {"stdlib": {"linux-arm64": ["stdc++"]}}}, "unsupported catalogue stdlib target key"),
    ]:
        subject = name + "_" + case + "_subject"
        test = name + "_" + case + "_test"
        _invalid_metadata(name = subject, metadata = json.encode(metadata), tags = ["manual"])
        _failure_test(name = test, target_under_test = subject, message = message)
        tests.append(test)
    native.test_suite(name = name, tests = tests)
