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

host_tool_features = struct(
    SUPPORTS_ARG_FILE = "supports_arg_file",
)

toolchain_tools = [
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

def host_os_key(rctx):
    (os, version, arch) = os_version_arch(rctx)
    if version == "":
        return "%s-%s" % (os, arch)
    else:
        return "%s-%s-%s" % (os, version, arch)

_known_distros = ["freebsd", "suse", "ubuntu", "arch", "manjaro", "debian", "fedora", "centos", "amzn", "raspbian", "pop", "rhel"]

def _linux_dist(rctx):
    res = rctx.execute(["cat", "/etc/os-release"])
    if res.return_code:
        fail("Failed to detect machine architecture: \n%s\n%s" % (res.stdout, res.stderr))
    info = {}
    for l in res.stdout.splitlines():
        parts = l.split("=", 1)
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
        print("`%s` attribute missing for key '%s' in repository '%s'; checking with key '%s'" % (attr_name, key1, rctx.name, key2))
    if key2 in d:
        return (key2, d.get(key2))

    if debug:
        print("`%s` attribute missing for key '%s' in repository '%s'; checking with key ''" % (attr_name, key2, rctx.name))
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

def list_to_string(l):
    if l == None:
        return "None"
    return "[{}]".format(", ".join(["\"{}\"".format(d) for d in l]))

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

# Tries to figure out if a tool supports newline separated arg files (i.e.
# `@file`).
def _tool_supports_arg_file(rctx, tool_path):
    # We assume nothing other than that `tool_path` is an executable.
    #
    # First we have to find out what command line flag gets the tool to just
    # print out some text and exit successfully.
    #
    # Most tools support `-v` or `--version` or (for `libtool`) `-V` but some
    # tools don't have such an option (BSD `ranlib` and `ar`, for example).
    #
    # We just try all the options we know of until one works and if none work
    # we return "None" indicating an indeterminate result.
    opts = (
        ["-v", "--version", "-version", "-V"] +
        ["-h", "--help", "-help", "-H"]
    )

    no_op_opt = None
    for opt in opts:
        if rctx.execute([tool_path, opt], timeout = 2).return_code == 0:
            no_op_opt = opt
            break

    if no_op_opt == None:
        return None

    # Okay! Once we have an opt that we *know* does nothing but make the
    # executable exit successfully, we'll stick that opt in a file and try
    # again:
    tmp_file = "tmp-arg-file"
    rctx.file(tmp_file, content = "{}\n".format(no_op_opt), executable = False)

    res = rctx.execute([tool_path, "@{}".format(tmp_file)]).return_code == 0
    rctx.delete(tmp_file)

    return res

def _get_host_tool_info(rctx, tool_path, features_to_test = [], tool_key = None):
    if tool_key == None:
        tool_key = tool_path

    if tool_path == None or not rctx.path(tool_path).exists:
        return {}

    f = host_tool_features
    features = {}
    for feature in features_to_test:
        features[feature] = {
            f.SUPPORTS_ARG_FILE: _tool_supports_arg_file,
        }[feature](rctx, tool_path)

    return {
        tool_key: struct(
            path = tool_path,
            features = features,
        ),
    }

def _extract_tool_path_and_features(tool_info):
    # Have to support structs or dicts:
    tool_path = tool_info.path if type(tool_info) == "struct" else tool_info["path"]
    tool_features = tool_info.features if type(tool_info) == "struct" else tool_info["features"]

    return (tool_path, tool_features)

def _check_host_tool_supports(host_tool_info, tool_key, features = []):
    if tool_key in host_tool_info:
        _, tool_features = _extract_tool_path_and_features(host_tool_info[tool_key])

        for f in features:
            if not f in tool_features or not tool_features[f]:
                return False

        return True
    else:
        return False

def _get_host_tool_and_assert_supports(host_tool_info, tool_key, features = []):
    if tool_key in host_tool_info:
        tool_path, tool_features = _extract_tool_path_and_features(host_tool_info[tool_key])

        missing = [f for f in features if not f in tool_features or not tool_features[f]]

        if missing:
            fail("Host tool `{key}` (`{path}`) is missing these features: `{missing}`.".format(
                key = tool_key,
                path = tool_path,
                missing = missing,
            ))

        return tool_path
    else:
        return False

host_tools = struct(
    get_tool_info = _get_host_tool_info,
    tool_supports = _check_host_tool_supports,
    get_and_assert = _get_host_tool_and_assert_supports,
)
