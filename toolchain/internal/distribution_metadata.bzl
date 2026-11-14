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
    if type(requirements) != "dict" or any([k not in ["features", "stdlib", "targets"] for k in requirements]):
        fail("catalogue requirements must contain only features and stdlib and targets")
    targets = requirements.get("targets", [])
    if type(targets) != "list" or any([t not in SUPPORTED_PLATFORM_KEYS for t in targets]):
        fail("catalogue targets must be a list of supported target-platform keys")
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
    if "target_runtimes" in meta:
        runtimes = meta["target_runtimes"]
        if type(runtimes) != "dict" or not runtimes:
            fail("catalogue target_runtimes must map target-platform keys to archive filename templates")
        result["target_runtimes"] = {}
        for target, archive in runtimes.items():
            if target not in SUPPORTED_PLATFORM_KEYS:
                fail("unsupported catalogue runtime target-platform key '{}'".format(target))
            if type(archive) != "string" or not archive:
                fail("catalogue target runtime archive must be a nonempty filename template")
            result["target_runtimes"][target] = archive.format(version = version)
    if "overlays" in meta:
        result["overlays"] = _catalogue_overlays(meta["overlays"], version)
    return result

def _catalogue_overlays(overlays, version):
    if type(overlays) != "dict":
        fail("catalogue overlays must map output directories to version/platform archives")
    result = {}
    for output, releases in overlays.items():
        if not output or output.startswith(".") or any([c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" for c in output.elems()]):
            fail("invalid catalogue overlay directory '{}': use a simple directory name".format(output))
        if type(releases) != "dict" or version not in releases:
            fail("catalogue overlay '{}' has no archive matching LLVM {}".format(output, version))
        platforms = releases[version]
        if type(platforms) != "dict" or not platforms:
            fail("catalogue overlay '{}' must map execution platforms to archive descriptors".format(output))
        result[output] = {}
        for platform, entry in platforms.items():
            if platform not in SUPPORTED_PLATFORM_KEYS:
                fail("unsupported catalogue overlay execution-platform key '{}'".format(platform))
            if type(entry) != "dict" or any([key not in ["url", "sha256", "strip_prefix"] for key in entry]):
                fail("catalogue overlay descriptors accept only url, sha256 and strip_prefix")
            url = entry.get("url")
            sha256 = entry.get("sha256")
            if type(url) != "string" or not url:
                fail("catalogue overlay '{}' requires a download URL".format(output))
            if type(sha256) != "string" or len(sha256) != 64 or any([c not in "0123456789abcdef" for c in sha256.lower().elems()]):
                fail("catalogue overlay '{}' requires a 64-character hexadecimal SHA-256".format(output))
            if type(entry.get("strip_prefix", "")) != "string":
                fail("catalogue overlay strip_prefix must be a string")
            result[output][platform] = dict(entry, url = url.format(version = version))
    return result

def resolve_distribution_overlays(metadata, platform, libcxx_url = ""):
    """Select exact-version companion archives before downloading a compiler."""
    overlays = metadata.get("overlays", {})
    if libcxx_url and "libcxx-msan" in overlays:
        fail("catalogue already supplies libcxx-msan; remove libcxx_url/libcxx_sha256 rather than mixing runtime sources")
    selected = {}
    for output, platforms in overlays.items():
        if platform not in platforms:
            # A cross-only compiler (e.g. macOS -> Linux MSan) has no native
            # overlay. Its target runtime repositories supply the overlays.
            if metadata.get("target_runtimes") and platform not in metadata["target_runtimes"]:
                continue
            fail("catalogue overlay '{}' has no archive for execution platform {}".format(output, platform))
        selected[output] = platforms[platform]
    return selected

def resolve_target_runtime_archives(metadata, distributions, version):
    """Resolve companion runtime archives from the same pinned catalogue data."""
    result = {}
    for target, archive in metadata.get("target_runtimes", {}).items():
        if archive not in distributions:
            fail("catalogue target runtime '{}' for {} is not in the selected distribution data".format(archive, target))
        info = distributions[archive]
        if info.version_string != version:
            fail("catalogue target runtime '{}' must match compiler LLVM {}, not {}".format(archive, version, info.version_string))
        if target not in info.metadata.get("platforms", []):
            fail("catalogue target runtime '{}' does not declare platform {}".format(archive, target))
        result[target] = info
    return result

def check_distribution_requirements(distribution, requirements, target, stdlib, features, disabled_features = []):
    """Reject a selected archive's incompatible configuration during analysis."""
    if requirements.get("targets") and target not in requirements["targets"]:
        fail("INCOMPATIBLE LLVM DISTRIBUTION '{}': target {} is not supported; use one of {}.".format(distribution, target, requirements["targets"]))
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

def catalogue_target_roots(metadata, repositories, roots, explicit_roots, execution_platform, sysroots):
    """Add target runtimes only for configured cross targets, respecting user roots."""
    result = dict(roots)
    for target in metadata.get("target_runtimes", {}):
        if target == execution_platform or explicit_roots.get(target, explicit_roots.get("")):
            continue
        if not sysroots.get(target, sysroots.get("")):
            continue
        if target not in repositories:
            fail("no runtime repository declared for catalogue target {}".format(target))
        result[target] = repositories[target]
    return result

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
