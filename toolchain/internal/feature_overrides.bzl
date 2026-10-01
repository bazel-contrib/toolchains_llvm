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

"""Feature predicates and complete toolchain variant selection."""

load("//toolchain/internal:common.bzl", "SUPPORTED_TARGETS", "os_arch_pair", "os_bzl", "supported_os_arch_keys")
load("//toolchain/internal:repo.bzl", "llvm_config_attrs", "llvm_repo_attrs")

def make_override(features = [], targets = [], reset = [], **settings):
    """Validate and construct a complete configuration override."""
    if not features:
        fail("feature override must have at least one feature condition")
    for feature in features:
        name = feature[1:] if feature.startswith("-") else feature
        if not name or name.startswith("-"):
            fail("invalid feature condition '{}': use a nonempty name or '-name' for exclusion".format(feature))
        if name in features and "-" + name in features:
            fail("feature '{}' is both required and excluded".format(name))
    for target in targets:
        if not target or target not in supported_os_arch_keys():
            fail("invalid feature override target '{}'".format(target))
    for key in list(settings.keys()) + reset:
        if key.startswith("_") or key in ["feature_condition", "feature_variants", "feature_base_llvm"] or (key not in llvm_config_attrs and key not in llvm_repo_attrs):
            fail("unknown or internal toolchain override attribute '{}'".format(key))
    return dict(features = features, targets = targets, reset = reset, settings = settings)

def _constraints(kind):
    result = {}
    for os, arch in SUPPORTED_TARGETS:
        if kind == "os":
            result[Label("@platforms//os:" + os_bzl(os))] = os
        else:
            result[Label("@platforms//cpu:" + arch)] = arch
    return result

def select_override(overrides, features, disabled_features = [], target = None):
    """Return the unique matching variant, or 'default'; reject ambiguity."""
    active = {feature: True for feature in features if feature not in disabled_features}
    matches = []
    for index, override in enumerate(overrides):
        if override.get("targets") and target not in override["targets"]:
            continue
        if all([
            feature[1:] not in active if feature.startswith("-") else feature in active
            for feature in override["features"]
        ]):
            matches.append(str(index))
    if len(matches) > 1:
        fail("AMBIGUOUS FEATURE OVERRIDES: variants {} all match features {} for target {}. Make their feature conditions mutually exclusive.".format(
            ", ".join(matches),
            sorted(active.keys()),
            target,
        ))
    return matches[0] if matches else "default"

def _feature_selection_impl(ctx):
    operating_systems = [name for constraint, name in ctx.attr.os_constraints.items() if ctx.target_platform_has_constraint(constraint[platform_common.ConstraintValueInfo])]
    architectures = [name for constraint, name in ctx.attr.arch_constraints.items() if ctx.target_platform_has_constraint(constraint[platform_common.ConstraintValueInfo])]
    target = os_arch_pair(operating_systems[0], architectures[0]) if operating_systems and architectures else None
    return [config_common.FeatureFlagInfo(value = select_override(
        json.decode(ctx.attr.overrides),
        ctx.features,
        ctx.disabled_features,
        target,
    ))]

_feature_selection = rule(
    implementation = _feature_selection_impl,
    attrs = {
        "overrides": attr.string(mandatory = True),
        "os_constraints": attr.label_keyed_string_dict(default = _constraints("os")),
        "arch_constraints": attr.label_keyed_string_dict(default = _constraints("cpu")),
    },
)

def feature_conditions(name, overrides):
    """Declare configuration predicates shared by all variants of a toolchain."""
    _feature_selection(
        name = name,
        overrides = json.encode(overrides),
    )
    for variant in ["default"] + [str(index) for index in range(len(overrides))]:
        native.config_setting(
            name = "variant_" + variant,
            flag_values = {":" + name: variant},
            visibility = ["//visibility:public"],
        )

def _conditions_repo_impl(rctx):
    rctx.file("BUILD.bazel", """\
load({source}, "feature_conditions")
feature_conditions(name = "selection", overrides = {overrides})
""".format(source = repr(str(rctx.attr.source)), overrides = repr(json.decode(rctx.attr.overrides))))

feature_conditions_repository = repository_rule(
    implementation = _conditions_repo_impl,
    attrs = {
        "overrides": attr.string(mandatory = True),
        "source": attr.label(default = Label("//toolchain/internal:feature_overrides.bzl")),
    },
)

def merge_override(base, settings, reset = []):
    """Inherit settings, replacing dictionary entries and all other values."""
    result = dict(base)
    for key in reset:
        result.pop(key, None)
    for key, value in settings.items():
        if type(value) == "dict" and key not in reset:
            merged = dict(result.get(key, {}))
            merged.update(value)
            result[key] = merged
        else:
            result[key] = value

    # A version scalar supersedes its inherited per-platform counterpart.
    for scalar, mapping in [("llvm_version", "llvm_versions"), ("linker_version", "linker_versions")]:
        if scalar in settings and mapping not in settings:
            result.pop(mapping, None)
        elif mapping in settings and scalar not in settings:
            result.pop(scalar, None)
    return result

def can_share_llvm_archive(base, settings, reset = []):
    """Reuse a base download only when both configurations use that archive."""
    if base.get("toolchain_roots") or merge_override(base, settings, reset).get("toolchain_roots"):
        return False
    return not any([key in llvm_repo_attrs for key in list(settings.keys()) + reset])
