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
load(":distribution_metadata.bzl", "catalogue_metadata", "catalogue_target_roots", "check_distribution_requirements", "distribution_requirements", "resolve_distribution_overlays", "resolve_target_runtime_archives")
load(":distributions_repo.bzl", "archive_version", "load_distribution_files")
load(":llvm_distributions.bzl", "testing")

_ARCHIVE = "llvm-toolchain-minimal-23.1.2-linux-amd64-musl.tar.zst"
_META = {
    "strip_prefix": "",
    "platforms": {"linux-x86_64": "llvm-toolchain-minimal-{version}-linux-amd64-musl.tar.zst"},
    "requirements": {"features": ["-asan"], "stdlib": {"linux-x86_64": ["stdc++", "dynamic-stdc++"]}},
}

_OVERLAY = {"url": "https://example.test/{version}/libcxx-msan.tar.zst", "sha256": "0" * 64}
_OVERLAYS = {"libcxx-msan": {"23.1.2": {"linux-x86_64": _OVERLAY}}}

def _runtime_test_impl(ctx):
    env = unittest.begin(ctx)
    archive = "target-23.1.2-linux-aarch64.tar.zst"
    meta = catalogue_metadata({"target_runtimes": {"linux-aarch64": "target-{version}-linux-aarch64.tar.zst"}}, _ARCHIVE, "23.1.2")
    runtime = struct(version_string = "23.1.2", sha256 = "1" * 64, metadata = {"platforms": ["linux-aarch64"]})
    selected = resolve_target_runtime_archives(meta, {archive: runtime}, "23.1.2")
    asserts.equals(env, runtime, selected["linux-aarch64"])
    asserts.equals(env, {}, resolve_target_runtime_archives({}, {}, "23.1.2"))
    repositories = {"linux-aarch64": "@target_arm64//"}
    fallback = {"": "@compiler_x86//"}
    sysroots = {"linux-aarch64": "@arm_sysroot//:root"}
    asserts.equals(env, {"": "@compiler_x86//", "linux-aarch64": "@target_arm64//"}, catalogue_target_roots(meta, repositories, fallback, {}, "linux-x86_64", sysroots))
    asserts.equals(env, fallback, catalogue_target_roots(meta, repositories, fallback, {}, "linux-aarch64", sysroots))
    asserts.equals(env, fallback, catalogue_target_roots(meta, repositories, fallback, {}, "linux-x86_64", {}))
    explicit = {"linux-aarch64": "@user_runtime//"}
    asserts.equals(env, explicit, catalogue_target_roots(meta, repositories, explicit, explicit, "linux-x86_64", sysroots))
    asserts.equals(env, fallback, catalogue_target_roots(meta, repositories, fallback, fallback, "linux-x86_64", sysroots))
    asserts.equals(env, {"": "@compiler_x86//"}, fallback)
    return unittest.end(env)

def _invalid_runtime_impl(ctx):
    archive = "target-23.1.2-linux-aarch64.tar.zst"
    runtime = struct(version_string = "22.1.8" if ctx.attr.case == "version" else "23.1.2", metadata = {"platforms": ["linux-x86_64" if ctx.attr.case == "platform" else "linux-aarch64"]})
    resolve_target_runtime_archives({"target_runtimes": {"linux-aarch64": archive}}, {} if ctx.attr.case == "missing" else {archive: runtime}, "23.1.2")
    return []

_invalid_runtime = rule(implementation = _invalid_runtime_impl, attrs = {"case": attr.string()})

def _overlay_test_impl(ctx):
    env = unittest.begin(ctx)
    metadata = catalogue_metadata(dict(_META, overlays = _OVERLAYS), _ARCHIVE, "23.1.2")
    selected = resolve_distribution_overlays(metadata, "linux-x86_64")
    asserts.equals(env, ["libcxx-msan"], selected.keys())
    asserts.equals(env, "https://example.test/23.1.2/libcxx-msan.tar.zst", selected["libcxx-msan"]["url"])
    asserts.equals(env, "0" * 64, selected["libcxx-msan"]["sha256"])
    asserts.equals(env, {}, resolve_distribution_overlays({}, "linux-x86_64", "https://legacy.test/libcxx.tar.gz"))
    cross_only = dict(metadata, target_runtimes = {"linux-x86_64": "runtime"})
    asserts.equals(env, {}, resolve_distribution_overlays(cross_only, "darwin-aarch64"))
    asserts.equals(env, selected, resolve_distribution_overlays(cross_only, "linux-x86_64"))
    return unittest.end(env)

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
_overlay_test = unittest.make(_overlay_test_impl)
_runtime_test = unittest.make(_runtime_test_impl)

def _invalid_overlay_impl(ctx):
    metadata = catalogue_metadata({"overlays": _OVERLAYS}, _ARCHIVE, "23.1.2")
    resolve_distribution_overlays(metadata, ctx.attr.platform, ctx.attr.libcxx_url)
    return []

_invalid_overlay = rule(implementation = _invalid_overlay_impl, attrs = {"platform": attr.string(), "libcxx_url": attr.string()})

def distribution_metadata_test_suite(name):
    """Validate profiles without downloading LLVM, including analysis errors."""
    unittest.suite(name + "_unit", _metadata_test, _merge_test, _selection_test, _requirements_test, _overlay_test, _runtime_test)
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
        ("unsupported_target", {"targets": ["linux-aarch64"]}, "builtin-libc++", "target linux-x86_64 is not supported"),
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
        ("overlay_version", {"overlays": {"libcxx-msan": {"22.1.8": {"linux-x86_64": _OVERLAY}}}}, "no archive matching LLVM 23.1.2"),
        ("overlay_path", {"overlays": {"../lib": {"23.1.2": {"linux-x86_64": _OVERLAY}}}}, "invalid catalogue overlay directory"),
        ("overlay_sha", {"overlays": {"libcxx-msan": {"23.1.2": {"linux-x86_64": dict(_OVERLAY, sha256 = "bad")}}}}, "hexadecimal SHA-256"),
        ("bad_runtime_map", {"target_runtimes": []}, "map target-platform keys"),
        ("bad_runtime_target", {"target_runtimes": {"linux-arm64": "foo"}}, "unsupported catalogue runtime target-platform key"),
        ("bad_runtime_archive", {"target_runtimes": {"linux-aarch64": []}}, "nonempty filename template"),
        ("bad_targets", {"requirements": {"targets": ["linux-arm64"]}}, "supported target-platform keys"),
    ]:
        subject = name + "_" + case + "_subject"
        test = name + "_" + case + "_test"
        _invalid_metadata(name = subject, metadata = json.encode(metadata), tags = ["manual"])
        _failure_test(name = test, target_under_test = subject, message = message)
        tests.append(test)
    for case, platform, libcxx_url, message in [
        ("overlay_platform", "linux-aarch64", "", "no archive for execution platform linux-aarch64"),
        ("overlay_conflict", "linux-x86_64", "https://legacy.test/libcxx.tar.gz", "rather than mixing runtime sources"),
    ]:
        subject = name + "_" + case + "_subject"
        test = name + "_" + case + "_test"
        _invalid_overlay(name = subject, platform = platform, libcxx_url = libcxx_url, tags = ["manual"])
        _failure_test(name = test, target_under_test = subject, message = message)
        tests.append(test)
    for case, message in [("missing", "not in the selected distribution data"), ("version", "must match compiler LLVM 23.1.2"), ("platform", "does not declare platform linux-aarch64")]:
        subject = name + "_runtime_" + case + "_subject"
        test = name + "_runtime_" + case + "_test"
        _invalid_runtime(name = subject, case = case, tags = ["manual"])
        _failure_test(name = test, target_under_test = subject, message = message)
        tests.append(test)
    native.test_suite(name = name, tests = tests)
