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

"""Target runtime repositories paired with an execution-platform compiler."""

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "get_auth")

def _download(rctx, archive, output = ""):
    urls = archive["urls"] if "urls" in archive else [archive["url"]]
    urls = ["file://" + url if url.startswith("/") else url for url in urls]
    rctx.download_and_extract(
        urls,
        sha256 = archive["sha256"],
        stripPrefix = archive.get("strip_prefix", ""),
        output = output,
        auth = get_auth(rctx, urls),
    )

def _runtime_impl(rctx):
    compiler_metadata = rctx.path(rctx.attr.compiler).dirname.get_child("distribution_metadata.json")
    metadata = json.decode(rctx.read(compiler_metadata))
    runtime = metadata.get("target_runtimes", {}).get(rctx.attr.target)
    if not runtime:
        fail("LLVM distribution '{}' has no catalogued runtime for target {}".format(metadata.get("archive", ""), rctx.attr.target))
    _download(rctx, runtime)
    for output, overlay in runtime["overlays"].items():
        _download(rctx, overlay, output)
    version = runtime["version"]
    major = int(version.split(".")[0])
    rctx.file("BUILD.bazel", rctx.read(rctx.attr.build_template).format(LLVM_VERSION = major if major >= 16 else version))
    rctx.file("distribution_metadata.json", json.encode(dict(runtime, target = rctx.attr.target)))
    if hasattr(rctx, "repo_metadata"):
        return rctx.repo_metadata(reproducible = True)
    return None

target_runtime_repository = repository_rule(
    implementation = _runtime_impl,
    attrs = {
        "compiler": attr.label(mandatory = True),
        "target": attr.string(mandatory = True),
        "netrc": attr.string(),
        "auth_patterns": attr.string_dict(),
        "build_template": attr.label(default = Label("//toolchain:BUILD.llvm_repo.tpl")),
    },
)
