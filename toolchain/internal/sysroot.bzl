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

load(":extra_targets.bzl", "sysroot_for_target")

def _darwin_sdk_path(rctx):
    if rctx.os.name != "mac os x":
        return ""

    exec_result = rctx.execute(["/usr/bin/xcrun", "--show-sdk-path", "--sdk", "macosx"])
    if exec_result.return_code:
        fail("Failed to detect OSX SDK path: \n%s\n%s" % (exec_result.stdout, exec_result.stderr))
    if exec_result.stderr:
        print(exec_result.stderr)
    return exec_result.stdout.strip()

def _default_host_sysroot(rctx):
    if rctx.os.name == "mac os x":
        return _darwin_sdk_path(rctx)
    else:
        return ""

# Takes a sysroot absolute path or label and returns a (path, label) pair.
#
# If given an absolute path, the label will be `None`.
def _process_sysroot(sysroot):
    # If the sysroot is an absolute path, use it as-is. Check for things that
    # start with "/" and not "//" to identify absolute paths, but also support
    # passing the sysroot as "/" to indicate the root directory.
    if sysroot[0] == "/" and (len(sysroot) == 1 or sysroot[1] != "/"):
        return (sysroot, None)

    sysroot = Label(sysroot)
    if sysroot.workspace_root:
        return (sysroot.workspace_root + "/" + sysroot.package, sysroot)
    else:
        return (sysroot.package, sysroot)

# Checks if the user has explicitly specified a sysroot for the given target; if they
# have then it uses that.
#
# If not, this function consults `extra_targets.bzl%sysroot_for_target`.
#
# If that comes up empty, this function falls back to the default sysroot for the host.
def target_sysroot_path(rctx, target_triple):
    sysroot = None

    # Try for an explicitly specified sysroot first:
    if rctx.os.name == "linux": sysroot = rctx.attr.sysroot.get("linux_{}".format(target_triple))
    elif rctx.os.name == "mac os x": sysroot = rctx.attr.sysroot.get("darwin_{}".format(target_triple))
    else:
        fail("Unsupported OS: " + rctx.os.name)

    if sysroot: return _process_sysroot(sysroot)

    # If that didn't work, consult `sysroot_for_target`:
    sysroot = sysroot_for_target(rctx, target_triple)

    # `sysroot_for_target` always returns a Label but it's fine; we can still
    # call `_process_sysroot_`
    if sysroot: return _process_sysroot(sysroot)

    # Finally, as a last resort just use the default sysroot (an absolute path):
    return (_default_host_sysroot(rctx), None)

# Return the sysroot path and the label to the files, if sysroot is not a system path.
def host_sysroot_path(rctx):
    if rctx.os.name == "linux":
        sysroot = rctx.attr.sysroot.get("linux", default = "")
    elif rctx.os.name == "mac os x":
        sysroot = rctx.attr.sysroot.get("darwin", default = "")
    else:
        fail("Unsupported OS: " + rctx.os.name)

    if not sysroot:
        return (_default_host_sysroot(rctx), None)

