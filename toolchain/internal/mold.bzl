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

_MOLD_RELEASES = {
    "2.42.1": {
        "linux-aarch64": "16b025652d3d7456689e6025a77e1903bb2a15e7630877c26cc133f5df95b9c6",
        "linux-x86_64": "6ff270c9bf07d2bec5c98aa324eb7c4daf6a1a4d815c05ff1708049616047855",
    },
}

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

def _mold_repository_impl(rctx):
    platform = "{}-{}".format(_normalize_os(rctx), _normalize_arch(rctx))
    releases = _MOLD_RELEASES.get(rctx.attr.version)
    if not releases:
        fail("unsupported mold version '{}'; supported versions: {}".format(
            rctx.attr.version,
            ", ".join(sorted(_MOLD_RELEASES.keys())),
        ))
    sha256 = releases.get(platform)
    if not sha256:
        fail("mold {} has no prebuilt executable for the {} execution platform".format(rctx.attr.version, platform))

    archive_platform = {
        "linux-aarch64": "aarch64-linux",
        "linux-x86_64": "x86_64-linux",
    }[platform]
    basename = "mold-{}-{}".format(rctx.attr.version, archive_platform)
    rctx.download_and_extract(
        "https://github.com/rui314/mold/releases/download/v{version}/{basename}.tar.gz".format(
            version = rctx.attr.version,
            basename = basename,
        ),
        sha256 = sha256,
        stripPrefix = basename,
    )
    rctx.file("BUILD.bazel", """\
package(default_visibility = ["//visibility:public"])

exports_files(["bin/mold"])

filegroup(
    name = "mold",
    srcs = ["bin/mold"],
)
""")

mold_repository = repository_rule(
    implementation = _mold_repository_impl,
    attrs = {
        "exec_arch": attr.string(),
        "exec_os": attr.string(),
        "version": attr.string(mandatory = True),
    },
)
