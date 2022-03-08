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

SUPPORTED_TARGETS = [("linux", "x86_64"), ("linux", "aarch64"), ("darwin", "x86_64")]

host_tool_features = struct(
    SUPPORTS_ARG_FILE = "supports_arg_file",
)

def python(rctx):
    # Get path of the python interpreter.

    python3 = rctx.which("python3")
    python = rctx.which("python")
    python2 = rctx.which("python2")
    if python3:
        return python3
    elif python:
        return python
    elif python2:
        return python2
    else:
        fail("python not found")

def os(rctx):
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
    exec_result = rctx.execute([
        python(rctx),
        "-c",
        "import platform; print(platform.machine())",
    ])
    if exec_result.return_code:
        fail("Failed to detect machine architecture: \n%s\n%s" % (exec_result.stdout, exec_result.stderr))
    return exec_result.stdout.strip()

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

def canonical_dir_path(path):
    if not path.endswith("/"):
        return path + "/"
    return path

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
    types = []
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
