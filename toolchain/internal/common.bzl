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

def get_host_tool_info(rctx, tool_path, features_to_test = [], tool_key = None):
    if tool_key == None: tool_key = tool_path

    if tool_path == None or not rctx.path(tool_path).exists:
        return {}

    f = host_tool_features
    features = {}
    for feature in features_to_test:
        features[feature] = {
        }[feature](rctx, tool_path)

    return {
        tool_key: struct(
            path = tool_path,
            features = features,
        )
    }

def check_host_tool_supports(host_tool_info, tool_key, features = []):
    if tool_key in host_tool_info:
        tool = host_tool_info[tool_key]

        for f in features:
            if not f in tool:
                return False
            if not tool[f]:
                return False

        return True
    else:
        return False

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
