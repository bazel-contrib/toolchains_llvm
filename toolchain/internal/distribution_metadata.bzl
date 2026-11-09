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

"""Provider-neutral catalogue metadata and configuration requirements."""

load(":platforms.bzl", "SUPPORTED_PLATFORM_KEYS")

def catalogue_metadata(meta, basename, version):
    """Expand optional file-wide metadata for a checksum entry."""
    result = {}
    for key in ["version", "strip_prefix", "requirements"]:
        if key in meta:
            result[key] = meta[key]
    if "version" in result and (type(result["version"]) != "string" or not result["version"]):
        fail("catalogue version must be a nonempty string")
    if "strip_prefix" in result and type(result["strip_prefix"]) != "string":
        fail("catalogue strip_prefix must be a string")
    if "platforms" in meta:
        platforms = meta["platforms"]
        if type(platforms) != "dict" or any([type(p) != "string" for p in platforms.values()]):
            fail("catalogue platforms must map execution-platform keys to archive filename templates")
        for platform in platforms:
            if platform not in SUPPORTED_PLATFORM_KEYS:
                fail("unsupported catalogue execution-platform key '{}'".format(platform))
        result["platforms"] = [platform for platform, pattern in platforms.items() if pattern.format(version = version) == basename]
        if not result["platforms"]:
            fail("catalogue platforms do not match archive '{}'".format(basename))
    requirements = result.get("requirements", {})
    if type(requirements) != "dict" or any([k not in ["features", "stdlib"] for k in requirements]):
        fail("catalogue requirements must contain only features and stdlib")
    features = requirements.get("features", [])
    if type(features) != "list" or any([type(f) != "string" or not f or f.startswith("--") or f == "-" for f in features]):
        fail("catalogue features must be a list of names or '-name' exclusions")
    for feature in features:
        if "-" + feature in features:
            fail("catalogue feature '{}' is both required and excluded".format(feature))
    stdlibs = requirements.get("stdlib", {})
    if type(stdlibs) != "dict" or any([type(v) != "list" or not v or any([type(s) != "string" for s in v]) for v in stdlibs.values()]):
        fail("catalogue stdlib must map target-platform keys to nonempty lists of standard libraries")
    for target in stdlibs:
        if target and target not in SUPPORTED_PLATFORM_KEYS:
            fail("unsupported catalogue stdlib target key '{}'".format(target))
    return result

def check_distribution_requirements(distribution, requirements, target, stdlib, features, disabled_features = []):
    """Reject a selected archive's incompatible configuration during analysis."""
    active = [f for f in features if f not in disabled_features]
    for feature in requirements.get("features", []):
        excluded = feature.startswith("-")
        name = feature[1:] if excluded else feature
        if (name in active) == excluded:
            fail("INCOMPATIBLE LLVM DISTRIBUTION '{}': feature '{}' must be {}. Configure a feature override to select a compatible distribution.".format(distribution, name, "disabled" if excluded else "enabled"))
    stdlibs = requirements.get("stdlib", {})
    allowed = stdlibs.get(target, stdlibs.get("", []))
    family = "dynamic-stdc++" if stdlib.startswith("dynamic-stdc++-") else "stdc++" if stdlib.startswith("stdc++-") else stdlib
    if allowed and stdlib not in allowed and family not in allowed:
        fail("INCOMPATIBLE LLVM DISTRIBUTION '{}': stdlib '{}' is not supported for {}; use one of {}.".format(distribution, stdlib, target, allowed))

def _requirements_impl(ctx):
    # Toolchain target_settings are evaluated in the consuming configuration,
    # unlike cc_toolchain file inputs (exec-configured on older Bazel).
    # Do not reject an inactive feature-override variant during resolution.
    matches_platform = all([ctx.target_platform_has_constraint(c[platform_common.ConstraintValueInfo]) for c in ctx.attr.target_constraints])
    if matches_platform and (not ctx.attr.selection or ctx.attr.selection[config_common.FeatureFlagInfo].value == ctx.attr.variant):
        check_distribution_requirements(ctx.attr.distribution, json.decode(ctx.attr.requirements), ctx.attr.target, ctx.attr.stdlib, ctx.features, ctx.disabled_features)
    return [DefaultInfo(), config_common.FeatureFlagInfo(value = "compatible")]

distribution_requirements = rule(
    implementation = _requirements_impl,
    attrs = {
        "distribution": attr.string(mandatory = True),
        "requirements": attr.string(mandatory = True),
        "target": attr.string(mandatory = True),
        "stdlib": attr.string(mandatory = True),
        "selection": attr.label(),
        "variant": attr.string(),
        "target_constraints": attr.label_list(),
    },
)
