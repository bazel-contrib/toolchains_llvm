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

"""Downloads versioned linker executables from the linker catalogue."""

load("//toolchain/internal:common.bzl", "is_absolute_path")
load("//toolchain/internal:distributions_repo.bzl", "load_jsonc")
load("//toolchain/internal:llvm_distributions.bzl", "resolve_version")

def catalogued_linker_reference(selection, version, target = ""):
    """Return the catalogue reference for a linker selection, or None."""
    if not selection:
        if version:
            fail("linker version '{}' has no linker selection for target '{}'".format(version, target))
        return None
    if selection == "auto" or is_absolute_path(selection):
        if version:
            fail("linker version '{}' cannot be used with linker selection '{}' for target '{}'".format(version, selection, target))
        return None
    return "{}@{}".format(selection, version) if version else selection

def _normalize_os(rctx):
    if rctx.attr.exec_os:
        return rctx.attr.exec_os
    if rctx.os.name == "linux":
        return "linux"
    if rctx.os.name == "mac os x":
        return "darwin"
    if rctx.os.name.startswith("windows"):
        return "windows"
    return rctx.os.name

def _normalize_arch(rctx):
    arch = rctx.attr.exec_arch or rctx.os.arch
    if arch in ["amd64", "x86_64"]:
        return "x86_64"
    if arch in ["arm64", "aarch64"]:
        return "aarch64"
    return arch

def _parse_reference(reference):
    parts = reference.split("@")
    if len(parts) != 2 or not parts[0] or not parts[1]:
        fail("invalid internal linker reference '{}'".format(reference))
    return parts[0], parts[1]

def _merge_catalogue(catalogue, extra):
    """Merge a linker catalogue into catalogue at platform granularity."""
    for linker, versions in extra.items():
        if linker == "_meta":
            continue
        merged_versions = catalogue.get(linker)
        if merged_versions == None:
            merged_versions = {}
            catalogue[linker] = merged_versions
        for version, platforms in versions.items():
            merged_platforms = merged_versions.get(version)
            if merged_platforms == None:
                merged_platforms = {}
                merged_versions[version] = merged_platforms
            merged_platforms.update(platforms)

def resolve_linker_distribution(catalogue, linker, version_selection, platform):
    """Resolve a version against releases available for an execution platform."""
    versions = catalogue.get(linker)
    if not versions:
        fail("unknown linker '{}'; known linkers: {}".format(linker, ", ".join(sorted(catalogue.keys()))))
    available_versions = [
        version
        for version, platforms in versions.items()
        if platform in platforms
    ]
    if not available_versions:
        fail("linker '{}' has no executable for the {} execution platform".format(linker, platform))
    version = resolve_version(version_selection, available_versions)
    return version, versions[version][platform]

def _mold_version(rctx):
    if not rctx.attr.mold_source:
        fail("bare `mold` requires linker_version/linker_versions or the injected mold module repository")
    source = rctx.path(rctx.attr.mold_source)
    prefix = "project(mold VERSION "
    for line in rctx.read("{}/CMakeLists.txt".format(source.dirname.dirname)).splitlines():
        line = line.strip()
        if line.startswith(prefix) and line.endswith(")"):
            return line[len(prefix):-1]
    fail("could not determine the mold version from the mold module's CMakeLists.txt")

def _linker_distributions_repository_impl(rctx):
    catalogue = {}
    if rctx.attr.use_builtin_catalogue:
        _merge_catalogue(catalogue, load_jsonc(rctx, rctx.attr.catalogue))
    for catalogue_file in rctx.attr.extra_catalogues:
        _merge_catalogue(catalogue, load_jsonc(rctx, catalogue_file))
    platform = "{}-{}".format(_normalize_os(rctx), _normalize_arch(rctx))
    manifest = {}

    for index, reference in enumerate(sorted(rctx.attr.linkers)):
        if reference == "mold":
            linker, version_selection = "mold", _mold_version(rctx)
        else:
            linker, version_selection = _parse_reference(reference)
        _, distribution = resolve_linker_distribution(catalogue, linker, version_selection, platform)

        extraction_dir = "_extract/{}".format(index)
        rctx.download_and_extract(
            distribution["urls"],
            output = extraction_dir,
            sha256 = distribution["sha256"],
            stripPrefix = distribution.get("strip_prefix", ""),
        )
        output = "bin/linker_{}".format(index)
        rctx.file(
            output,
            rctx.read("{}/{}".format(extraction_dir, distribution["binary"])),
            executable = True,
            legacy_utf8 = False,
        )
        manifest[reference] = {
            "linker_features": distribution.get("linker_features", []),
            "path": output,
        }

    rctx.file("linkers.json", json.encode(manifest) + "\n")
    rctx.file("BUILD.bazel", """\
package(default_visibility = ["//visibility:public"])

exports_files(["linkers.json"])
""")

linker_distributions_repository = repository_rule(
    implementation = _linker_distributions_repository_impl,
    attrs = {
        "catalogue": attr.label(
            allow_single_file = [".json", ".jsonc"],
            default = Label("//toolchain/distributions:linkers.jsonc"),
        ),
        "exec_arch": attr.string(),
        "exec_os": attr.string(),
        "extra_catalogues": attr.label_list(allow_files = [".json", ".jsonc"]),
        "linkers": attr.string_list(mandatory = True),
        "mold_source": attr.label(allow_single_file = True),
        "use_builtin_catalogue": attr.bool(default = True),
    },
)

def _linker_version_test_writer_impl(ctx):
    available = ["2.40.4", "2.41.0", "2.42.0", "2.42.1"]
    selections = [
        "2.41.0",
        "first",
        "latest",
        "latest:<2.42.1",
        "first:>=2.41.0",
        "latest:>=2.40.0,!=2.42.1",
    ]
    version_results = [
        "{} -> {}".format(selection, resolve_version(selection, available))
        for selection in selections
    ]
    reference_results = [
        "{} + {} -> {}".format(selection or "<empty>", version or "<empty>", catalogued_linker_reference(selection, version))
        for selection, version in [
            ("gold", "1.2.3"),
            ("lld", "19.1.7"),
            ("mold", ""),
            ("auto", ""),
            ("/usr/bin/ld", ""),
            ("", ""),
        ]
    ]
    catalogue = {
        "test": {
            "1.0.0": {
                "linux-x86_64": {"binary": "old"},
            },
            "2.0.0": {
                "darwin-aarch64": {"binary": "new", "linker_features": ["start_end_lib"]},
            },
        },
    }
    _merge_catalogue(catalogue, {
        "test": {
            "1.0.0": {
                "linux-x86_64": {"binary": "override", "linker_features": ["start_end_lib"]},
            },
            "3.0.0": {
                "linux-x86_64": {"binary": "extra"},
            },
        },
    })
    linux_version, linux_distribution = resolve_linker_distribution(catalogue, "test", "latest", "linux-x86_64")
    darwin_version, darwin_distribution = resolve_linker_distribution(catalogue, "test", "latest", "darwin-aarch64")
    platform_results = [
        "latest linux-x86_64 -> {} {}".format(linux_version, "start_end_lib" in linux_distribution.get("linker_features", [])),
        "latest darwin-aarch64 -> {} {}".format(darwin_version, "start_end_lib" in darwin_distribution.get("linker_features", [])),
        "merged override -> {}".format(catalogue["test"]["1.0.0"]["linux-x86_64"]["binary"]),
    ]
    ctx.actions.write(ctx.outputs.out, "\n".join(version_results + reference_results + platform_results) + "\n")

linker_version_test_writer = rule(
    implementation = _linker_version_test_writer_impl,
    outputs = {"out": "%{name}.txt"},
)
