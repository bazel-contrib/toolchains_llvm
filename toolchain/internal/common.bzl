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

SUPPORTED_OS_ARCH = ["linux-x86_64", "linux-aarch64", "darwin-x86_64"]

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

def arch(rctx):
    exec_result = rctx.execute([
        python(rctx),
        "-c",
        "import platform; print(platform.machine())",
    ])
    if exec_result.return_code:
        fail("Failed to detect machine architecture: \n%s\n%s" % (exec_result.stdout, exec_result.stderr))
    return exec_result.stdout.strip()

def os_arch_pair(shortos, arch):
    return "{}-{}".format(shortos, arch)

def check_os_arch_keys(keys):
    for k in keys:
        if k and k not in SUPPORTED_OS_ARCH:
            fail("Unsupported {{os}}-{{arch}} key: {key}; valid keys are: {keys}".format(
                key = k,
                keys = ", ".join(SUPPORTED_OS_ARCH),
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
