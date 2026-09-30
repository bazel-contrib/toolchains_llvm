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

def _selection_test_impl(ctx):
    env = unittest.begin(ctx)
    overrides = [
        dict(features = ["arbitrary", "second"], not_features = ["excluded"]),
        dict(features = ["another"], targets = ["linux-x86_64"]),
        dict(features = [], not_features = ["arbitrary", "another", "no_negative"]),
    ]
    asserts.equals(env, "0", select_override(overrides, ["arbitrary", "second", "unrelated"]))
    asserts.equals(env, "default", select_override(overrides, ["arbitrary"]))
    asserts.equals(env, "default", select_override(overrides, ["arbitrary", "second", "excluded"]))
    asserts.equals(env, "default", select_override(overrides, ["arbitrary", "second"], ["second"]))
    asserts.equals(env, "1", select_override(overrides, ["another"], target = "linux-x86_64"))
    asserts.equals(env, "default", select_override(overrides, ["another"], target = "darwin-aarch64"))
    asserts.equals(env, "2", select_override(overrides, []))
    asserts.equals(env, "default", select_override([], ["anything"]))
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
        llvm_feature_override(features = ["a"], not_features = ["a"])
    elif case == "empty":
        llvm_feature_override(features = [])
    elif case == "unknown":
        llvm_feature_override(features = ["a"], unknown_setting = "bad")
    elif case == "internal":
        llvm_feature_override(features = ["a"], reset = ["feature_condition"])
    elif case == "target":
        llvm_feature_override(features = ["a"], targets = ["invalid"])
    elif case == "signed":
        llvm_feature_override(features = ["-a"])
    return []

def _archive_sharing_test_impl(ctx):
    env = unittest.begin(ctx)
    base = dict(llvm_version = "23.1.2")
    asserts.true(env, can_share_llvm_archive(base, dict(cxx_standard = {"": "c++20"})))
    asserts.false(env, can_share_llvm_archive(base, dict(llvm_version = "22.1.8")))
    asserts.false(env, can_share_llvm_archive(base, {}, reset = ["distribution"]))
    asserts.false(env, can_share_llvm_archive(base, dict(toolchain_roots = {"": "/opt/llvm"})))

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
_inheritance_test = unittest.make(_inheritance_test_impl)
_archive_sharing_test = unittest.make(_archive_sharing_test_impl)

def feature_overrides_test_suite(name):
    """Test positive, negative and ambiguous predicates, and attribute merging."""
    tests = []
    for case, message in {
        "ambiguous": "AMBIGUOUS FEATURE OVERRIDES",
        "contradictory": "both required and excluded",
        "empty": "must have a features or not_features condition",
        "unknown": "unknown or internal toolchain override attribute",
        "internal": "unknown or internal toolchain override attribute",
        "target": "invalid feature override target",
        "signed": "feature names must be nonempty and unsigned",
    }.items():
        _invalid(name = name + "_" + case + "_subject", case = case, tags = ["manual"])
        _invalid_test(name = name + "_" + case + "_test", target_under_test = name + "_" + case + "_subject", message = message)
        tests.append(name + "_" + case + "_test")
    _selection_test(name = name + "_selection_test")
    _inheritance_test(name = name + "_inheritance_test")
    _archive_sharing_test(name = name + "_archive_sharing_test")
    native.test_suite(name = name, tests = tests + [name + "_selection_test", name + "_inheritance_test", name + "_archive_sharing_test"])
