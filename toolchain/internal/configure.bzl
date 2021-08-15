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
    "@com_grail_bazel_toolchain//toolchain/internal:extra_targets.bzl",
    _cpu_constraints = "cpu_constraints",
    _split_target_triple = "split_target_triple",
    _target_triple_to_constraints = "target_triple_to_constraints",
)
load(
    "@com_grail_bazel_toolchain//toolchain/internal:llvm_distributions.bzl",
    _download_llvm = "download_llvm",
    _download_llvm_preconfigured = "download_llvm_preconfigured",
)
load(
    "@com_grail_bazel_toolchain//toolchain/internal:sysroot.bzl",
    _sysroot_path = "sysroot_path",
)
load("@rules_cc//cc:defs.bzl", _cc_toolchain = "cc_toolchain")

def _makevars_ld_flags(rctx):
    if rctx.os.name == "mac os x":
        return ""

    # lld, as of LLVM 7, is experimental for Mach-O, so we use it only on linux.
    return "-fuse-ld=lld"

def _include_dirs_str(rctx, host_platform):
    dirs = rctx.attr.cxx_builtin_include_directories.get(host_platform)
    if not dirs:
        return ""
    return ("\n" + 12 * " ").join(["\"%s\"," % d for d in dirs])

def _extra_toolchains_for_toolchain_suite(target_triple):
    arch, _vendor, _os, _env = _split_target_triple(target_triple)
    cpu_constraints = _cpu_constraints(arch)

    # This is more than a little broken.
    #
    # `cc_toolchain_suite` only allows us to associate a toolchain with a
    # particular `--cpu` and `--compiler` value and does not provide any way
    # to "select" a toolchain based on the host platform, just on the target
    # cpu. So, we are unable to add the macOS toolchains to the suite.
    #
    # See: https://docs.bazel.build/versions/main/be/c-cpp.html#cc_toolchain_suite.toolchains
    #
    # Worse, absent documentation/consensus for what values of `--cpu` are
    # commonly used, we just use the CPU values for the `@platforms//cpu`
    # constraint; these may or may not match what is commonly used and what
    # users are putting in their platform mappings.
    #
    # See: https://docs.bazel.build/versions/main/platforms-intro.html#platform-mappings
    #
    # Since toolchain resolution is what will be supported in the future (for
    # which we do the right thing), this isn't the end of the world. It's
    # unclear if it's possible for us to do better here though. (TODO)

    if len(cpu_constraints) > 0:
        return "# For `{}`:".format(target_triple) + ''.join([
        """
        "{cpu}": ":cc-clang-linux_${target}",
        "{cpu}|clang": ":cc-clang-linux_${target}",\n""".format(
            cpu = cpu,
            target = target_triple,
        )
            for cpu in cpu_constraints
        ])
    else:
        return ""


def _extra_cc_toolchain_config(target_triple):
    target_constraints = _target_triple_to_constraints(target_triple)

    return """
# For `{target}`:

cc_toolchain_config(
    name = "local_linux_{target}",
    host_platform = "k8",
    # TODO
)

cc_toolchain_config(
    name = "local_darwin_{target}",
    host_platform = "darwin",
    # TODO
)

toolchain(
    name = "cc-toolchain-linux_{target}",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
    target_compatible_with = [
        {target_constraints}
    ],
    toolchain = ":cc-clang-linux_{target}",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

toolchain(
    name = "cc-toolchain-darwin_{target}",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:osx",
    ],
    target_compatible_with = [
        {target_constraints}
    ],
    toolchain = ":cc-clang-darwin_{target}",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)
""".format(
    target = target_triple,
    target_constraints = '\n        '.join([
        '"{}",'.format(c) for c in target_constraints
    ])
)

def _extra_conditional_cc_toolchain_config(rctx, target_triple):
    absolute_paths = rctx.attr.absolute_paths

    return """
# For `{target}`:
conditional_cc_toolchain("cc-clang-linux_{target}", ":local_linux_{target}", False, {abs_paths})
conditional_cc_toolchain("cc-clang-darwin_{target}", ":local_darwin_{target}", True, {abs_paths})
""".format(
        target = target_triple,
        abs_paths = absolute_paths,
    )

def llvm_toolchain_impl(rctx):
    if rctx.os.name.startswith("windows"):
        rctx.file("BUILD")
        rctx.file("toolchains.bzl", """
def llvm_register_toolchains():
    pass
        """)
        return

    repo_path = str(rctx.path(""))
    relative_path_prefix = "external/%s/" % rctx.name
    if rctx.attr.absolute_paths:
        toolchain_path_prefix = (repo_path + "/")
    else:
        toolchain_path_prefix = relative_path_prefix

    sysroot_path, sysroot = _sysroot_path(rctx)
    substitutions = {
        "%{repo_name}": rctx.name,
        "%{llvm_version}": rctx.attr.llvm_version,
        "%{bazel_version}": native.bazel_version,
        "%{toolchain_path_prefix}": toolchain_path_prefix,
        "%{tools_path_prefix}": (repo_path + "/") if rctx.attr.absolute_paths else "",
        "%{debug_toolchain_path_prefix}": relative_path_prefix,
        "%{sysroot_path}": sysroot_path,
        "%{sysroot_prefix}": "%sysroot%" if sysroot_path else "",
        "%{sysroot_label}": "\"%s\"" % str(sysroot) if sysroot else "",
        "%{absolute_paths}": "True" if rctx.attr.absolute_paths else "False",
        "%{makevars_ld_flags}": _makevars_ld_flags(rctx),
        "%{k8_additional_cxx_builtin_include_directories}": _include_dirs_str(rctx, "k8"),
        "%{darwin_additional_cxx_builtin_include_directories}": _include_dirs_str(rctx, "darwin"),

        "%{extra_cc_toolchain_config}": '\n'.join([
            _extra_cc_toolchain_config(t) for t in rctx.attr.extra_targets
        ]),
        "%{extra_conditional_cc_toolchain_config}": '\n'.join([
            _extra_conditional_cc_toolchain_config(rctx, t) for t in rctx.attr.extra_targets
        ]),
        "%{extra_toolchains_for_toolchain_suite}": '        \n'.join([
            _extra_toolchains_for_toolchain_suite(t) for t in rctx.attr.extra_targets
        ]),
        "%{extra_toolchains_for_registration}": '        \n'.join([
            "# For `{target}`:\n".format(target = target) + ''.join([
                """        "@{repo}//:cc-toolchain-{host}_{target}",\n""".format(
                    repo = rctx.name,
                    host = host,
                    target = target,
                )
                for host in ["linux", "darwin"]
            ])
            for target in rctx.attr.extra_targets
        ]),
    }

    rctx.template(
        "toolchains.bzl",
        Label("@com_grail_bazel_toolchain//toolchain:toolchains.bzl.tpl"),
        substitutions,
    )
    rctx.template(
        "cc_toolchain_config.bzl",
        Label("@com_grail_bazel_toolchain//toolchain:cc_toolchain_config.bzl.tpl"),
        substitutions,
    )
    rctx.template(
        "bin/cc_wrapper.sh",  # Co-located with the linker to help rules_go.
        Label("@com_grail_bazel_toolchain//toolchain:cc_wrapper.sh.tpl"),
        substitutions,
    )
    rctx.template(
        "Makevars",
        Label("@com_grail_bazel_toolchain//toolchain:Makevars.tpl"),
        substitutions,
    )
    rctx.template(
        "BUILD",
        Label("@com_grail_bazel_toolchain//toolchain:BUILD.tpl"),
        substitutions,
    )

    rctx.symlink("/usr/bin/ar", "bin/ar")  # For GoLink.

    # For GoCompile on macOS; compiler path is set from linker path.
    # It also helps clang driver sometimes for the linker to be colocated with the compiler.
    rctx.symlink("/usr/bin/ld", "bin/ld")
    if rctx.os.name == "linux":
        rctx.symlink("/usr/bin/ld.gold", "bin/ld.gold")
    else:
        # Add dummy file for non-linux so we don't have to put conditional logic in BUILD.
        rctx.file("bin/ld.gold")

    # Repository implementation functions can be restarted, keep expensive ops at the end.
    if not _download_llvm(rctx):
        _download_llvm_preconfigured(rctx)

def conditional_cc_toolchain(name, toolchain_config, host_is_darwin, absolute_paths = False):
    # Toolchain macro for BUILD file to use conditional logic.
    if absolute_paths:
        _cc_toolchain(
            name = name,
            all_files = ":empty",
            compiler_files = ":empty",
            dwp_files = ":empty",
            linker_files = ":empty",
            objcopy_files = ":empty",
            strip_files = ":empty",
            supports_param_files = 0 if host_is_darwin else 1,
            toolchain_config = toolchain_config,
        )
    else:
        extra_files = [":cc_wrapper"] if host_is_darwin else []
        native.filegroup(name = name + "-all-files", srcs = [":all_components"] + extra_files)
        native.filegroup(name = name + "-archiver-files", srcs = [":ar"] + extra_files)
        native.filegroup(name = name + "-assembler-files", srcs = [":as"] + extra_files)
        native.filegroup(name = name + "-compiler-files", srcs = [":compiler_components"] + extra_files)
        native.filegroup(name = name + "-linker-files", srcs = [":linker_components"] + extra_files)
        _cc_toolchain(
            name = name,
            all_files = name + "-all-files",
            ar_files = name + "-archiver-files",
            as_files = name + "-assembler-files",
            compiler_files = name + "-compiler-files",
            dwp_files = ":empty",
            linker_files = name + "-linker-files",
            objcopy_files = ":objcopy",
            strip_files = ":empty",
            supports_param_files = 0 if host_is_darwin else 1,
            toolchain_config = toolchain_config,
        )
