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

"""Regression tests for feature matching and complete configuration inheritance."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts", "unittest")
load(":feature_overrides.bzl", "can_share_llvm_archive", "merge_override", "select_override", llvm_feature_override = "make_override")
load(":repo.bzl", "llvm_repo_attrs")

def _selection_test_impl(ctx):
    env = unittest.begin(ctx)
    overrides = [
        dict(features = ["arbitrary", "second", "-excluded"]),
        dict(features = ["another"], targets = ["linux-x86_64"]),
        dict(features = ["-arbitrary", "-another", "-no_negative"]),
    ]
    asserts.equals(env, "0", select_override(overrides, ["arbitrary", "second", "unrelated"]))
    asserts.equals(env, "default", select_override(overrides, ["arbitrary"]))
    asserts.equals(env, "default", select_override(overrides, ["arbitrary", "second", "excluded"]))
    asserts.equals(env, "0", select_override(overrides, ["arbitrary", "second", "excluded"], ["excluded"]))
    asserts.equals(env, "default", select_override(overrides, ["arbitrary", "second"], ["second"]))
    asserts.equals(env, "1", select_override(overrides, ["another"], target = "linux-x86_64"))
    asserts.equals(env, "default", select_override(overrides, ["another"], target = "darwin-aarch64"))
    asserts.equals(env, "2", select_override(overrides, []))
    asserts.equals(env, "2", select_override(overrides, ["arbitrary"], ["arbitrary"]))
    asserts.equals(env, "default", select_override(overrides, ["no_negative"]))
    asserts.equals(env, "default", select_override([], ["anything"]))
    return unittest.end(env)

def _signed_features_test_impl(ctx):
    env = unittest.begin(ctx)
    conditions = ["a", "-b", "a", "-b"]
    override = llvm_feature_override(features = conditions)
    asserts.equals(env, conditions, override["features"])
    asserts.equals(env, "0", select_override([override], ["a"]))
    asserts.equals(env, "0", select_override([override], ["a", "b"], ["b"]))
    asserts.equals(env, "default", select_override([override], ["a", "b"]))
    asserts.equals(env, "default", select_override([override], ["a"], ["a"]))
    negative_only = llvm_feature_override(features = ["-b"])
    asserts.equals(env, "0", select_override([negative_only], []))
    asserts.equals(env, "default", select_override([negative_only], ["b"]))
    return unittest.end(env)

def _inheritance_test_impl(ctx):
    env = unittest.begin(ctx)
    base = dict(
        llvm_versions = {"": "23.1.2"},
        linker_version = "latest",
        linker = {"linux-x86_64": "mold", "darwin-aarch64": "auto"},
        extra_compile_flags = {"": ["-DOLD"], "linux-x86_64": ["-DLINUX"]},
        use_builtin_linker_distributions = False,
        extra_linker_distribution_files = [Label("//:MODULE.bazel")],
    )
    merged = merge_override(base, dict(
        llvm_version = "22.1.8",
        linker_versions = {"linux-x86_64": "2.40.4"},
        linker = {"linux-x86_64": ""},
        extra_compile_flags = {"": ["-DNEW"]},
    ))
    asserts.equals(env, "22.1.8", merged["llvm_version"])
    asserts.false(env, "llvm_versions" in merged)
    asserts.false(env, "linker_version" in merged)
    asserts.equals(env, {"linux-x86_64": "", "darwin-aarch64": "auto"}, merged["linker"])
    asserts.equals(env, {"": ["-DNEW"], "linux-x86_64": ["-DLINUX"]}, merged["extra_compile_flags"])
    asserts.equals(env, base["extra_linker_distribution_files"], merged["extra_linker_distribution_files"])
    asserts.false(env, merged["use_builtin_linker_distributions"])
    cleared = merge_override(base, {"extra_compile_flags": {"": []}}, reset = ["extra_compile_flags", "use_builtin_linker_distributions"])
    asserts.equals(env, {"": []}, cleared["extra_compile_flags"])
    asserts.false(env, "use_builtin_linker_distributions" in cleared)
    asserts.equals(env, {"": ["-DOLD"], "linux-x86_64": ["-DLINUX"]}, base["extra_compile_flags"])
    asserts.equals(env, {"llvm_versions": {"": "22"}}, merge_override({"llvm_version": "23"}, {"llvm_versions": {"": "22"}}))
    return unittest.end(env)

def _invalid_impl(ctx):
    case = ctx.attr.case
    if case == "ambiguous":
        select_override([dict(features = ["a"]), dict(features = ["b"])], ["a", "b"])
    elif case == "contradictory":
        llvm_feature_override(features = ["a", "-a"])
    elif case == "negative_contradiction":
        llvm_feature_override(features = ["-a", "a"])
    elif case == "empty":
        llvm_feature_override(features = [])
    elif case == "unknown":
        llvm_feature_override(features = ["a"], unknown_setting = "bad")
    elif case == "internal":
        llvm_feature_override(features = ["a"], reset = ["feature_condition"])
    elif case == "target":
        llvm_feature_override(features = ["a"], targets = ["invalid"])
    elif case == "empty_name":
        llvm_feature_override(features = [""])
    elif case == "bare_minus":
        llvm_feature_override(features = ["-"])
    elif case == "double_minus":
        llvm_feature_override(features = ["--a"])
    return []

def _external_roots_base():
    return dict(
        llvm_version = "23.1.2",
        toolchain_roots = {"": "@llvm_k8//", "linux-aarch64": "@llvm_arm64//"},
        target_toolchain_roots = {"": "@llvm_k8//", "linux-aarch64": "@llvm_arm64//"},
        sysroot = {"linux-aarch64": "@arm64_sysroot//:root"},
    )

def _download_version_override_test_impl(ctx):
    env = unittest.begin(ctx)

    # Existing MBO/XFF-style use: ordinary builds download LLVM 23, whereas
    # MSan selects LLVM 22 and its matching instrumented libc++, without roots.
    base = dict(llvm_version = "23.1.2", linker = {"linux-x86_64": "mold"})
    msan = merge_override(base, dict(
        llvm_version = "22.1.8",
        libcxx_url = "https://example.test/libcxx-msan-22.1.8.tar.zst",
        linker = {"linux-x86_64": ""},
    ))
    asserts.equals(env, "22.1.8", msan["llvm_version"])
    asserts.equals(env, {"linux-x86_64": ""}, msan["linker"])
    asserts.equals(env, "https://example.test/libcxx-msan-22.1.8.tar.zst", msan["libcxx_url"])
    asserts.false(env, "toolchain_roots" in msan)
    asserts.false(env, "target_toolchain_roots" in msan)
    asserts.false(env, can_share_llvm_archive(base, {"llvm_version": "22.1.8"}))
    asserts.equals(env, "23.1.2", base["llvm_version"])
    return unittest.end(env)

def _distribution_roots_test_impl(ctx):
    env = unittest.begin(ctx)
    base = _external_roots_base()
    selection = {
        "llvm_version": "22.1.8",
        "llvm_versions": {"": "22.1.8"},
        "distribution": "clang+llvm-22.1.8.tar.xz",
        "urls": {"": ["https://example.test/llvm.tar.xz"]},
        "extra_llvm_distribution_files": [Label("//:MODULE.bazel")],
        "extra_llvm_distributions": {"llvm.tar.xz": "sha256"},
        "use_builtin_llvm_distributions": False,
        "libcxx_url": "https://example.test/libcxx-msan.tar.xz",
    }
    for key, value in selection.items():
        merged = merge_override(base, {key: value})
        asserts.false(env, "toolchain_roots" in merged, key)
        asserts.false(env, "target_toolchain_roots" in merged, key)
        asserts.equals(env, value, merged[key])
        asserts.equals(env, base["sysroot"], merged["sysroot"])
        asserts.false(env, can_share_llvm_archive(base, {key: value}))

    # Explicit intent, not a value comparison: even the same LLVM version
    # requests a distribution rather than inheriting a caller's installation.
    same_version = merge_override(base, {"llvm_version": base["llvm_version"]})
    asserts.false(env, "toolchain_roots" in same_version)
    asserts.false(env, "target_toolchain_roots" in same_version)
    for key in llvm_repo_attrs:
        # A reset to a download/selection default must not keep old roots either.
        merged = merge_override(base, {}, reset = [key])
        if key in ["exec_os", "exec_arch", "supported_platforms"]:
            asserts.equals(env, base["toolchain_roots"], merged["toolchain_roots"])
            asserts.equals(env, base["target_toolchain_roots"], merged["target_toolchain_roots"])
        else:
            asserts.false(env, "toolchain_roots" in merged, key)
            asserts.false(env, "target_toolchain_roots" in merged, key)

    # Never mutate the default configuration.
    asserts.equals(env, "@llvm_k8//", base["toolchain_roots"][""])
    asserts.equals(env, "@llvm_arm64//", base["target_toolchain_roots"]["linux-aarch64"])
    return unittest.end(env)

def _configuration_only_roots_test_impl(ctx):
    env = unittest.begin(ctx)
    base = _external_roots_base()
    for settings in [
        {},
        {"extra_compile_flags": {"": ["-DVARIANT"]}},
        {"linker": {"": "mold"}, "linker_version": "latest"},
        {"exec_os": "linux", "exec_arch": "aarch64", "supported_platforms": ["linux"]},
    ]:
        merged = merge_override(base, settings)
        asserts.equals(env, base["toolchain_roots"], merged["toolchain_roots"])
        asserts.equals(env, base["target_toolchain_roots"], merged["target_toolchain_roots"])
        asserts.equals(env, base["sysroot"], merged["sysroot"])

    # Without a distribution setting, explicit root entries still merge by key.
    roots_only = merge_override(base, {"toolchain_roots": {"": "@replacement_compiler//"}})
    asserts.equals(env, {"": "@replacement_compiler//", "linux-aarch64": "@llvm_arm64//"}, roots_only["toolchain_roots"])
    asserts.equals(env, base["target_toolchain_roots"], roots_only["target_toolchain_roots"])
    return unittest.end(env)

def _distribution_explicit_roots_test_impl(ctx):
    env = unittest.begin(ctx)
    base = _external_roots_base()

    # Explicit roots belong to the new distribution; do not merge old entries.
    explicit = dict(toolchain_roots = {"": "@new_compiler//"}, target_toolchain_roots = {"linux-aarch64": "@new_runtime//"})
    for keys in [["toolchain_roots"], ["target_toolchain_roots"], explicit.keys()]:
        settings = dict({key: explicit[key] for key in keys}, llvm_version = "22.1.8")
        merged = merge_override(base, settings)
        for key in explicit:
            if key in settings:
                asserts.equals(env, explicit[key], merged[key])
            else:
                asserts.false(env, key in merged)

    empty_roots = merge_override(base, dict(llvm_version = "22.1.8", toolchain_roots = {}, target_toolchain_roots = {}))
    asserts.equals(env, {}, empty_roots["toolchain_roots"])
    asserts.equals(env, {}, empty_roots["target_toolchain_roots"])
    asserts.equals(env, "@llvm_arm64//", base["toolchain_roots"]["linux-aarch64"])
    return unittest.end(env)

def _distribution_sysroot_test_impl(ctx):
    env = unittest.begin(ctx)
    base = _external_roots_base()
    for settings, reset, expected in [
        ({"llvm_version": "22.1.8"}, [], base["sysroot"]),
        ({"llvm_version": "22.1.8", "sysroot": {"linux-x86_64": "@x86_sysroot//:root"}}, [], {"linux-aarch64": "@arm64_sysroot//:root", "linux-x86_64": "@x86_sysroot//:root"}),
        ({"llvm_version": "22.1.8", "sysroot": {"linux-aarch64": "@new_arm_sysroot//:root"}}, [], {"linux-aarch64": "@new_arm_sysroot//:root"}),
        ({"llvm_version": "22.1.8"}, ["sysroot"], None),
    ]:
        merged = merge_override(base, settings, reset)
        asserts.equals(env, expected, merged.get("sysroot"))
        asserts.false(env, "toolchain_roots" in merged)
        asserts.false(env, "target_toolchain_roots" in merged)
    asserts.equals(env, {"linux-aarch64": "@arm64_sysroot//:root"}, base["sysroot"])
    return unittest.end(env)

def _archive_sharing_test_impl(ctx):
    env = unittest.begin(ctx)
    base = dict(llvm_version = "23.1.2")
    asserts.true(env, can_share_llvm_archive(base, dict(cxx_standard = {"": "c++20"})))
    asserts.false(env, can_share_llvm_archive(base, dict(llvm_version = "22.1.8")))
    asserts.false(env, can_share_llvm_archive(base, {}, reset = ["distribution"]))
    asserts.false(env, can_share_llvm_archive(base, dict(toolchain_roots = {"": "/opt/llvm"})))

    asserts.true(env, can_share_llvm_archive(base, dict(linker_version_allow_prereleases = True)))
    asserts.true(env, can_share_llvm_archive(base, {}, reset = ["linker_version_allow_prereleases"]))
    asserts.false(env, can_share_llvm_archive(base, dict(llvm_version_allow_prereleases = True)))
    asserts.false(env, can_share_llvm_archive(base, {}, reset = ["llvm_version_allow_prereleases"]))
    for llvm_allow in [False, True]:
        for linker_allow in [False, True]:
            settings = dict(llvm_version_allow_prereleases = llvm_allow, linker_version_allow_prereleases = linker_allow)
            override = llvm_feature_override(features = ["test"], **settings)
            merged = merge_override(dict(base, llvm_version_allow_prereleases = not llvm_allow, linker_version_allow_prereleases = not linker_allow), settings)
            asserts.equals(env, llvm_allow, merged["llvm_version_allow_prereleases"])
            asserts.equals(env, linker_allow, merged["linker_version_allow_prereleases"])
            asserts.equals(env, settings, override["settings"])

    # Resetting an external root must create a new download: the base has no
    # generated LLVM archive repository that the variant could share.
    external_base = dict(base, toolchain_roots = {"": "/opt/llvm"})
    asserts.false(env, can_share_llvm_archive(external_base, {}, reset = ["toolchain_roots"]))
    asserts.false(env, can_share_llvm_archive(external_base, {}))
    return unittest.end(env)

_invalid = rule(implementation = _invalid_impl, attrs = {"case": attr.string()})

def _invalid_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, ctx.attr.message)
    return analysistest.end(env)

_invalid_test = analysistest.make(_invalid_test_impl, expect_failure = True, attrs = {"message": attr.string()})
_selection_test = unittest.make(_selection_test_impl)
_signed_features_test = unittest.make(_signed_features_test_impl)
_inheritance_test = unittest.make(_inheritance_test_impl)
_archive_sharing_test = unittest.make(_archive_sharing_test_impl)
_distribution_roots_test = unittest.make(_distribution_roots_test_impl)
_download_version_override_test = unittest.make(_download_version_override_test_impl)
_configuration_only_roots_test = unittest.make(_configuration_only_roots_test_impl)
_distribution_explicit_roots_test = unittest.make(_distribution_explicit_roots_test_impl)
_distribution_sysroot_test = unittest.make(_distribution_sysroot_test_impl)

def feature_overrides_test_suite(name):
    """Test positive, negative and ambiguous predicates, and attribute merging."""
    tests = []
    for case, message in {
        "ambiguous": "AMBIGUOUS FEATURE OVERRIDES",
        "contradictory": "both required and excluded",
        "negative_contradiction": "both required and excluded",
        "empty": "must have at least one feature condition",
        "empty_name": "invalid feature condition",
        "bare_minus": "invalid feature condition",
        "double_minus": "invalid feature condition",
        "unknown": "unknown or internal toolchain override attribute",
        "internal": "unknown or internal toolchain override attribute",
        "target": "invalid feature override target",
    }.items():
        _invalid(name = name + "_" + case + "_subject", case = case, tags = ["manual"])
        _invalid_test(name = name + "_" + case + "_test", target_under_test = name + "_" + case + "_subject", message = message)
        tests.append(name + "_" + case + "_test")
    for suffix, test in {
        "selection": _selection_test,
        "signed_features": _signed_features_test,
        "inheritance": _inheritance_test,
        "archive_sharing": _archive_sharing_test,
        "download_version_override": _download_version_override_test,
        "distribution_roots": _distribution_roots_test,
        "configuration_only_roots": _configuration_only_roots_test,
        "distribution_explicit_roots": _distribution_explicit_roots_test,
        "distribution_sysroot": _distribution_sysroot_test,
    }.items():
        test(name = name + "_" + suffix + "_test")
        tests.append(name + "_" + suffix + "_test")
    native.test_suite(name = name, tests = tests)
