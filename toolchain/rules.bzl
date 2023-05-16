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
    implementation = _llvm_config_impl,
)

def llvm_toolchain(name, bzlmod = False, bzlmod_module_version = None, **kwargs):
    if kwargs.get("llvm_version") == kwargs.get("llvm_versions"):
        fail("Exactly one of llvm_version or llvm_versions must be set")

    if not kwargs.get("toolchain_roots"):
        llvm_args = {
            k: v
            for k, v in kwargs.items()
            if (k not in _llvm_config_attrs.keys()) or (k in _common_attrs.keys())
        }
        llvm_repository_name = name + "_llvm"
        llvm(name = name + "_llvm", **llvm_args)
        if bzlmod:
            if not bzlmod_module_version:
                bzlmod_module_version = "override"
            kwargs.update(toolchain_roots = {"": "@@com_grail_bazel_toolchain~{module_version}~llvm~{repository_name}//".format(
                module_version = bzlmod_module_version,
                repository_name = llvm_repository_name,
            )})
        else:
            kwargs.update(toolchain_roots = {"": "@%s_llvm//" % name})

    if not kwargs.get("llvm_versions"):
        kwargs.update(llvm_versions = {"": kwargs.get("llvm_version")})

    toolchain_args = {
        k: v
        for k, v in kwargs.items()
        if (k not in _llvm_repo_attrs.keys()) or (k in _common_attrs.keys())
    }
    toolchain(name = name, **toolchain_args)
