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

def _darwin_sdk_path(rctx):
    if rctx.os.name != "mac os x":
        return ""

    exec_result = rctx.execute(["/usr/bin/xcrun", "--show-sdk-path", "--sdk", "macosx"])
    if exec_result.return_code:
        fail("Failed to detect OSX SDK path: \n%s\n%s" % (exec_result.stdout, exec_result.stderr))
    if exec_result.stderr:
        print(exec_result.stderr)
    return exec_result.stdout.strip()

def _default_sysroot(rctx):
    if rctx.os.name == "mac os x":
        return _darwin_sdk_path(rctx)
    else:
        return ""

# Return the sysroot path and the label to the files, if sysroot is not a system path.
def sysroot_path(rctx):
    if rctx.os.name == "linux":
        sysroot = rctx.attr.sysroot.get("linux", default = "")
    elif rctx.os.name == "mac os x":
        sysroot = rctx.attr.sysroot.get("darwin", default = "")
    else:
        fail("Unsupported OS: " + rctx.os.name)

    if not sysroot:
        return (_default_sysroot(rctx), None)

    if sysroot[0] == "/" and sysroot[1] != "/":
        return (sysroot, None)

    sysroot = Label(sysroot)
    if sysroot.workspace_root:
        return (sysroot.workspace_root + "/" + sysroot.package, sysroot)
    else:
        return (sysroot.package, sysroot)
