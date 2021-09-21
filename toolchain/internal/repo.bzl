# Copyright 2021 The Bazel Authors.
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
    "//toolchain/internal:common.bzl",
    _arch = "arch",
    _check_os_arch_keys = "check_os_arch_keys",
    _os = "os",
    _os_arch_pair = "os_arch_pair",
)
load(
    "//toolchain/internal:llvm_distributions.bzl",
    _download_llvm = "download_llvm",
    _download_llvm_preconfigured = "download_llvm_preconfigured",
)

def llvm_repo_impl(rctx):
    _check_os_arch_keys(rctx.attr.urls)

    os = _os(rctx)
    if os == "windows":
        rctx.file("BUILD", executable = False)
        return
    arch = _arch(rctx)

    rctx.file(
        "BUILD.bazel",
        content = rctx.read(Label("//toolchain:BUILD.llvm_repo")),
        executable = False,
    )

    if not _download_llvm(rctx, _os_arch_pair(os, arch)):
        _download_llvm_preconfigured(rctx)

    # TODO: Are these symlinks still needed? Remove from here and
    # BUILD.llvm_repo if not. If these symlinks are removed, then we can
    # leverage http_archive rule instead of _download_llvm. Or maybe we can
    # still leverage it with a patch file.

    rctx.symlink("/usr/bin/ar", "bin/ar")  # For GoLink.

    # For GoCompile on macOS; compiler path is set from linker path.
    # It also helps clang driver sometimes for the linker to be colocated with the compiler.
    rctx.symlink("/usr/bin/ld", "bin/ld")
    if rctx.path("/usr/bin/ld.gold").exists:
        rctx.symlink("/usr/bin/ld.gold", "bin/ld.gold")
    else:
        # Add dummy file for non-linux so we don't have to put conditional logic in BUILD.
        rctx.file("bin/ld.gold")
