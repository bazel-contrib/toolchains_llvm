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

package(default_visibility = ["//visibility:public"])

load("@bazel_skylib//rules:native_binary.bzl", "native_binary")
load("@toolchains_llvm//toolchain/internal:system_module_map.bzl", "system_module_map")
load("@toolchains_llvm//toolchain/internal:host_sysroot_directory.bzl", "host_sysroot_directory")
load("@rules_cc//cc/toolchains:args.bzl", "cc_args")
load("@rules_cc//cc/toolchains:tool.bzl", "cc_tool")
load("@rules_cc//cc/toolchains:tool_map.bzl", "cc_tool_map")
load("@rules_cc//cc/toolchains:feature.bzl", "cc_feature")
load("@rules_cc//cc/toolchains:feature_constraint.bzl", "cc_feature_constraint")
load("@rules_cc//cc/toolchains:toolchain.bzl", "cc_toolchain")
load("@rules_cc//cc/toolchains/args:sysroot.bzl", "cc_sysroot")


cc_feature_constraint(
    name = "constraint_opt",
    all_of = ["@rules_cc//cc/toolchains/features:opt"],
)

cc_feature_constraint(
    name = "constraint_dbg",
    all_of = ["@rules_cc//cc/toolchains/features:dbg"],
)

cc_feature_constraint(
    name = "constraint_fastbuild",
    all_of = ["@rules_cc//cc/toolchains/features:fastbuild"],
)

# TODO: what's the non-legacy way of this doing this?
cc_feature_constraint(
    name = "constraint_unfiltered_compile_flags",
    all_of =  ["@rules_cc//cc/toolchains/features/legacy:unfiltered_compile_flags"]
)


# Do not resolve our symlinked resource prefixes to real paths.
cc_args(
    name = "no_absolute_paths_for_builtins",
    actions = [
        "@rules_cc//cc/toolchains/actions:compile_actions",
        "@rules_cc//cc/toolchains/actions:ar_actions",
    ],
    args =  ["-no-canonical-prefixes"],
    visibility = ["//visibility:public"],
)

# Following filegroup targets are used when not using absolute paths and shared
# between different toolchains.

# Tools symlinked through this repo. This target is for internal use in the toolchain only.
filegroup(
    name = "internal-use-symlinked-tools",
    srcs = [%{symlinked_tools}
    ],
    visibility = ["//visibility:private"],
)

# Tools wrapped through this repo. This target is for internal use in the toolchain only.
filegroup(
    name = "internal-use-wrapped-tools",
    srcs = [
        "%{wrapper_bin_prefix}cc_wrapper.sh",
    ],
    visibility = ["//visibility:private"],
)

# All internal use files.
filegroup(
    name = "internal-use-files",
    srcs = [
        ":internal-use-symlinked-tools",
        ":internal-use-wrapped-tools",
    ],
    visibility = ["//visibility:private"],
)

%{cc_toolchains}

# Convenience targets from the LLVM toolchain.
%{convenience_targets}
