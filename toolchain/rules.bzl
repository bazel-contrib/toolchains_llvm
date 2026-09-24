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

def llvm_toolchain(name, **kwargs):
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
    targets = {target: True for target in linkers.keys() + linker_versions.keys()}
    if kwargs.get("linker_version"):
        targets[""] = True
    catalogued_linkers = {}
    for target in targets.keys():
        selection = linkers.get(target, linkers.get("", ""))
        version = linker_versions.get(target, linker_versions.get("", ""))
        reference = catalogued_linker_reference(selection, version, target)
        if reference:
            catalogued_linkers[reference] = True
    catalogued_linkers = sorted(catalogued_linkers.keys())
    if catalogued_linkers:
        linker_distributions_repository(
            name = name + "_linkers",
            exec_arch = kwargs.get("exec_arch", ""),
            exec_os = kwargs.get("exec_os", ""),
            linkers = catalogued_linkers,
            mold_source = "@mold//:src/entry.cc" if "mold" in catalogued_linkers else None,
        )
        kwargs["linker_repository"] = "@{}_linkers//:linkers.json".format(name)

    if not kwargs.get("toolchain_roots"):
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
