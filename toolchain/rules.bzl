# Copyright 2018 The Bazel Authors.
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

load(
    "//toolchain/internal:configure.bzl",
    _llvm_config_impl = "llvm_config_impl",
)
load("//toolchain/internal:feature_overrides.bzl", "can_share_llvm_archive", "feature_conditions_repository", "make_override", "merge_override")
load(
    "//toolchain/internal:linker_distributions.bzl",
    "catalogued_linker_reference",
    "linker_distributions_repository",
)
load(
    "//toolchain/internal:repo.bzl",
    _common_attrs = "common_attrs",
    _llvm_config_attrs = "llvm_config_attrs",
    _llvm_repo_attrs = "llvm_repo_attrs",
    _llvm_repo_impl = "llvm_repo_impl",
)

llvm = repository_rule(
    attrs = _llvm_repo_attrs,
    local = False,
    implementation = _llvm_repo_impl,
)

toolchain = repository_rule(
    attrs = _llvm_config_attrs,
    local = True,
    configure = True,
    environ = [
        "DEVELOPER_DIR",
        "PATH",
        "SDKROOT",
    ],
    implementation = _llvm_config_impl,
)

def llvm_feature_override(features = [], targets = [], reset = [], **settings):
    """Override any public llvm_toolchain settings under build features.

    Args:
      features: Required build features; prefix a name with '-' to require it
        to be absent or disabled. All conditions must match.
      targets: Optional target OS/architecture keys limiting the condition.
      reset: Inherited attribute names to reset before applying settings.
      **settings: Ordinary llvm_toolchain attributes to override.

    Returns:
      An override for llvm_toolchain's feature_overrides list.
    """
    return make_override(features = features, targets = targets, reset = reset, **settings)

def llvm_toolchain(name, feature_overrides = [], **kwargs):
    """Create a toolchain and optional complete variants selected by features."""
    if feature_overrides:
        conditions_name = name + "_feature_conditions"
        feature_conditions_repository(
            name = conditions_name,
            overrides = json.encode([{key: override[key] for key in ["features", "targets"]} for override in feature_overrides]),
        )
        manifests = []
        for index, override in enumerate(feature_overrides):
            variant_name = name + "_feature_" + str(index)
            variant = merge_override(kwargs, override["settings"], override["reset"])

            # Reuse the base archive when only toolchain configuration changes.
            # This still permits overrides of every distribution attribute.
            if can_share_llvm_archive(kwargs, override["settings"], override["reset"]):
                variant["feature_base_llvm"] = "@{}//:BUILD.bazel".format(name + "_llvm")
            variant["feature_condition"] = "@{}//:variant_{}".format(conditions_name, index)
            _llvm_toolchain(name = variant_name, **variant)
            manifests.append("@{}//:toolchain_manifest.json".format(variant_name))
        kwargs["feature_condition"] = "@{}//:variant_default".format(conditions_name)
        kwargs["feature_variants"] = manifests
    _llvm_toolchain(name = name, **kwargs)

def _llvm_toolchain(name, **kwargs):
    if kwargs.get("llvm_version") and kwargs.get("llvm_versions"):
        fail("Exactly one of llvm_version or llvm_versions must be set")
    if not kwargs.get("llvm_versions"):
        if not kwargs.get("llvm_version"):
            fail("One of llvm_version or llvm_versions must be set")
        kwargs.update(llvm_versions = {"": kwargs.get("llvm_version")})

    if kwargs.get("linker_version") and kwargs.get("linker_versions"):
        fail("Exactly one of linker_version or linker_versions must be set")
    if kwargs.get("linker_version") and not kwargs.get("linker_versions"):
        kwargs["linker_versions"] = {"": kwargs["linker_version"]}

    linkers = kwargs.get("linker", {})
    linker_versions = kwargs.get("linker_versions", {})
    targets = {target: True for target in linkers.keys()}
    targets.update({target: True for target in linker_versions.keys() if target})
    if not linkers and linker_versions.get(""):
        targets[""] = True
    catalogued_linkers = {}
    for target in targets.keys():
        selection = linkers.get(target, linkers.get("", ""))
        version = linker_versions.get(target, linker_versions.get("", ""))
        reference = catalogued_linker_reference(selection, version)
        if reference:
            catalogued_linkers[target] = reference
    if catalogued_linkers:
        linker_distributions_repository(
            name = name + "_linkers",
            exec_arch = kwargs.get("exec_arch", ""),
            exec_os = kwargs.get("exec_os", ""),
            extra_catalogues = kwargs.get("extra_linker_distribution_files", []),
            linkers = catalogued_linkers,
            mold_source = "@mold//:src/entry.cc" if "mold" in catalogued_linkers.values() else None,
            use_builtin_catalogue = kwargs.get("use_builtin_linker_distributions", True),
        )
        kwargs["linker_repository"] = "@{}_linkers//:linkers.json".format(name)

    if not kwargs.get("toolchain_roots") and not kwargs.get("feature_base_llvm"):
        llvm_args = {
            k: v
            for k, v in kwargs.items()
            if (k not in _llvm_config_attrs.keys()) or (k in _common_attrs.keys())
        }
        llvm(name = name + "_llvm", **llvm_args)

    toolchain_args = {
        k: v
        for k, v in kwargs.items()
        if (k not in _llvm_repo_attrs.keys()) or (k in _common_attrs.keys())
    }
    toolchain(name = name, **toolchain_args)
