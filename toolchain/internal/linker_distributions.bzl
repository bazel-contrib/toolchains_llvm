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

load("//toolchain/internal:distributions_repo.bzl", "load_jsonc")

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
        fail("invalid versioned linker reference '{}'; expected <linker>@<version>".format(reference))
    return parts[0], parts[1]

def _mold_version(rctx):
    if not rctx.attr.mold_source:
        fail("bare `mold` requires the mold module repository; use `mold@<version>` for an explicit catalogue version")
    source = rctx.path(rctx.attr.mold_source)
    prefix = "project(mold VERSION "
    for line in rctx.read("{}/CMakeLists.txt".format(source.dirname.dirname)).splitlines():
        line = line.strip()
        if line.startswith(prefix) and line.endswith(")"):
            return line[len(prefix):-1]
    fail("could not determine the mold version from the mold module's CMakeLists.txt")

def _linker_distributions_repository_impl(rctx):
    catalogue = load_jsonc(rctx, rctx.attr.catalogue)
    platform = "{}-{}".format(_normalize_os(rctx), _normalize_arch(rctx))
    manifest = {}

    for index, reference in enumerate(sorted(rctx.attr.linkers)):
        if reference == "mold":
            linker, version = "mold", _mold_version(rctx)
        else:
            linker, version = _parse_reference(reference)
        versions = catalogue.get(linker)
        if not versions:
            fail("unknown linker '{}'; known linkers: {}".format(linker, ", ".join(sorted(catalogue.keys()))))
        platforms = versions.get(version)
        if not platforms:
            fail("unsupported {} version '{}'; supported versions: {}".format(
                linker,
                version,
                ", ".join(sorted(versions.keys())),
            ))
        distribution = platforms.get(platform)
        if not distribution:
            fail("{} {} has no executable for the {} execution platform".format(linker, version, platform))

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
        manifest[reference] = output

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
        "linkers": attr.string_list(mandatory = True),
        "mold_source": attr.label(allow_single_file = True),
    },
)
