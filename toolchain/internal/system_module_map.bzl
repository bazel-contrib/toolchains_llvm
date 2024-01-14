# Copyright 2024 The Bazel Authors.
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

def _system_module_map(ctx):
    module_map = ctx.actions.declare_file(ctx.attr.name + ".modulemap")

    # The builtin include directories are relative to the execroot, but the
    # paths in the module map must be relative to the directory that contains
    # the module map.
    to_execroot = (module_map.dirname.count("/") + 1) * "../"

    dirs = []
    non_hermetic = False
    for dir in ctx.attr.cxx_builtin_include_directories:
        if ctx.attr.sysroot_path and dir.startswith("%sysroot%"):
            dir = ctx.attr.sysroot_path + dir[len("%sysroot%"):]
        if dir.startswith("/"):
            non_hermetic = True
        else:
            dir = to_execroot + dir
        dir = dir.replace("//", "/")
        dirs.append(dir)

    # If the action references a file outside of the execroot, it isn't safe to
    # cache or run remotely.
    execution_requirements = {}
    if non_hermetic:
        execution_requirements = {
            "no-cache": "",
            "no-remote": "",
        }

    ctx.actions.run_shell(
        outputs = [module_map],
        inputs = ctx.attr.toolchain[DefaultInfo].files,
        arguments = [
            ctx.executable._generate_system_module_map.path,
            module_map.path,
        ] + dirs,
        tools = [ctx.executable._generate_system_module_map],
        command = """
"$1" "${@:3}" > "$2"
""",
        execution_requirements = execution_requirements,
        mnemonic = "LlvmSystemModuleMap",
        progress_message = "Generating system module map",
    )
    return DefaultInfo(files = depset([module_map]))

system_module_map = rule(
    doc = """Generates a Clang module map for the toolchain and sysroot headers.""",
    implementation = _system_module_map,
    attrs = {
        "toolchain": attr.label(mandatory = True),
        "cxx_builtin_include_directories": attr.string_list(mandatory = True),
        "sysroot_path": attr.string(),
        "_generate_system_module_map": attr.label(
            default = "@bazel_tools//tools/cpp:generate_system_module_map.sh",
            allow_single_file = True,
            cfg = "exec",
            executable = True,
        ),
    },
)
