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
load("//toolchain/internal:mold.bzl", "mold_repository")
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

    uses_mold = "mold" in kwargs.get("linker", {}).values()
    if uses_mold:
        mold_version = kwargs.get("mold_version")
        mold_binary = kwargs.get("mold_binary")
        if bool(mold_version) == bool(mold_binary):
            fail("A toolchain selecting mold must set exactly one of mold_version or mold_binary")
        if mold_version:
            mold_repository(
                name = name + "_mold",
                exec_arch = kwargs.get("exec_arch", ""),
                exec_os = kwargs.get("exec_os", ""),
                version = mold_version,
            )
            kwargs["mold_binary"] = "@{}_mold//:mold".format(name)
    elif kwargs.get("mold_version") or kwargs.get("mold_binary"):
        fail("mold_version and mold_binary require a `mold` linker selection")

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
