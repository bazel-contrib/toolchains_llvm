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

SUPPORTED_TARGETS = [("linux", "x86_64"), ("linux", "aarch64"), ("darwin", "x86_64"), ("darwin", "aarch64")]

_toolchain_tools = [
    "clang-cpp",
    "ld.lld",
    "llvm-ar",
    "llvm-dwp",
    "llvm-profdata",
    "llvm-cov",
    "llvm-nm",
    "llvm-objcopy",
    "llvm-objdump",
    "llvm-strip",
]

_toolchain_tools_darwin = [
    "llvm-libtool-darwin",
]

def host_os_key(rctx):
    (os, version, arch) = os_version_arch(rctx)
    if version == "":
        return "%s-%s" % (os, arch)
    else:
        return "%s-%s-%s" % (os, version, arch)

_known_distros = ["freebsd", "suse", "ubuntu", "arch", "manjaro", "debian", "fedora", "centos", "amzn", "raspbian", "pop", "rhel"]

def _linux_dist(rctx):
    info = {}
    for line in rctx.read("/etc/os-release").splitlines():
        parts = line.split("=", 1)
        if len(parts) == 1:
            continue
        info[parts[0]] = parts[1]

    distname = info["ID"].strip('\"')

    if distname not in _known_distros:
        for distro in info["ID_LIKE"].strip('\"').split(" "):
            if distro in _known_distros:
                distname = distro
                break

    version = ""
    if "VERSION_ID" in info:
        version = info["VERSION_ID"].strip('"')

    return distname, version

def os_version_arch(rctx):
    _os = os(rctx)
    _arch = arch(rctx)

    if _os == "linux":
        (distname, version) = _linux_dist(rctx)
        return distname, version, _arch

    return _os, "", _arch

def os(rctx):
    # Less granular host OS name, e.g. linux.

    name = rctx.os.name
    if name == "linux":
        return "linux"
    elif name == "mac os x":
        return "darwin"
    elif name.startswith("windows"):
        return "windows"
    fail("Unsupported OS: " + name)

def os_bzl(os):
    # Return the OS string as used in bazel platform constraints.
    return {"darwin": "osx", "linux": "linux"}[os]

def arch(rctx):
    arch = rctx.os.arch
    if arch == "arm64":
        return "aarch64"
    if arch == "amd64":
        return "x86_64"
    return arch

def os_arch_pair(os, arch):
    return "{}-{}".format(os, arch)

_supported_os_arch = [os_arch_pair(os, arch) for (os, arch) in SUPPORTED_TARGETS]

def supported_os_arch_keys():
    return _supported_os_arch

def check_os_arch_keys(keys):
    for k in keys:
        if k and k not in _supported_os_arch:
            fail("Unsupported {{os}}-{{arch}} key: {key}; valid keys are: {keys}".format(
                key = k,
                keys = ", ".join(_supported_os_arch),
            ))

def host_os_arch_dict_value(rctx, attr_name, debug = False):
    # Gets a value from a dictionary keyed by host OS and arch.
    # Checks for the more specific key, then the less specific,
    # and finally the empty key as fallback.
    # Returns a tuple of the matching key and value.

    d = getattr(rctx.attr, attr_name)
    key1 = host_os_key(rctx)
    if key1 in d:
        return (key1, d.get(key1))

    key2 = os_arch_pair(os(rctx), arch(rctx))
    if debug:
        print("`%s` attribute missing for key '%s' in repository '%s'; checking with key '%s'" % (attr_name, key1, rctx.name, key2))  # buildifier: disable=print
    if key2 in d:
        return (key2, d.get(key2))

    if debug:
        print("`%s` attribute missing for key '%s' in repository '%s'; checking with key ''" % (attr_name, key2, rctx.name))  # buildifier: disable=print
    return ("", d.get(""))  # Fallback to empty key.

def canonical_dir_path(path):
    if not path.endswith("/"):
        return path + "/"
    return path

def pkg_name_from_label(label):
    if label.workspace_name:
        return "@" + label.workspace_name + "//" + label.package
    else:
        return label.package

def pkg_path_from_label(label):
    if label.workspace_root:
        return label.workspace_root + "/" + label.package
    else:
        return label.package

def list_to_string(ls):
    if ls == None:
        return "None"
    return "[{}]".format(", ".join(["\"{}\"".format(d) for d in ls]))

def attr_dict(attr):
    # Returns a mutable dict of attr values from the struct. This is useful to
    # return updated attribute values as return values of repository_rule
    # implementations.

    tuples = []
    for key in dir(attr):
        if not hasattr(attr, key):
            fail("key %s not found in attributes" % key)
        val = getattr(attr, key)

        # Make mutable copies of frozen types.
        typ = type(val)
        if typ == "dict":
            val = dict(val)
        elif typ == "list":
            val = list(val)
        elif typ == "builtin_function_or_method":
            # Functions can not be compared.
            continue

        tuples.append((key, val))

    return dict(tuples)

def toolchain_tools(os):
    tools = list(_toolchain_tools)
    if os == "darwin":
        tools.extend(_toolchain_tools_darwin)
    return tools

def _get_host_tool_info(rctx, tool_path, tool_key = None):
    if tool_key == None:
        tool_key = tool_path

    if tool_path == None or not rctx.path(tool_path).exists:
        return {}

    return {
        tool_key: struct(
            path = tool_path,
            features = [],
        ),
    }

def _extract_tool_path(tool_info):
    # Have to support structs or dicts:
    return tool_info.path if type(tool_info) == "struct" else tool_info["path"]

def _get_host_tool(host_tool_info, tool_key):
    if tool_key in host_tool_info:
        return _extract_tool_path(host_tool_info[tool_key])
    else:
        return None

host_tools = struct(
    get_tool_info = _get_host_tool_info,
    get_and_assert = _get_host_tool,
)
