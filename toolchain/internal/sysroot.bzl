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
    "//toolchain/internal:common.bzl",
    _os_arch_pair = "os_arch_pair",
    _pkg_path_from_label = "pkg_path_from_label",
)

def _darwin_sdk_path(rctx):
    exec_result = rctx.execute(["/usr/bin/xcrun", "--show-sdk-path", "--sdk", "macosx"])
    if exec_result.return_code:
        fail("Failed to detect OSX SDK path: \n%s\n%s" % (exec_result.stdout, exec_result.stderr))
    if exec_result.stderr:
        print(exec_result.stderr)
    return exec_result.stdout.strip()

# Default sysroot path can be used when the user has not provided an explicit
# sysroot for the target, and when host platform is the same as target
# platform.
def default_sysroot_path(rctx, os):
    if os == "darwin":
        return _darwin_sdk_path(rctx)
    else:
        return ""

# Return the sysroot path and the label to the files, if sysroot is not a system path.
def sysroot_path(sysroot_dict, os, arch):
    sysroot = sysroot_dict.get(_os_arch_pair(os, arch))
    if not sysroot:
        return (None, None)

    # If the sysroot is an absolute path, use it as-is. Check for things that
    # start with "/" and not "//" to identify absolute paths, but also support
    # passing the sysroot as "/" to indicate the root directory.
    if sysroot[0] == "/" and (len(sysroot) == 1 or sysroot[1] != "/"):
        return (sysroot, None)

    sysroot_path = _pkg_path_from_label(Label(sysroot))
    return (sysroot_path, sysroot)
