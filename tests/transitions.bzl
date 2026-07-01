"""Helper transitions for tests."""

# Copyright 2022 The Bazel Authors.
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

# This transition function sets `--features=per_object_debug_info` and
# `--fission` as well as the compilation mode.
#
# These three Bazel flags influence whether or not `.dwo` and `.dwp` are
# created.
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc:defs.bzl", "CcInfo", "DebugPackageInfo")

def _fission_transition_impl(settings, attr):
    features = settings["//command_line_option:features"]
    if "per_object_debug_info" in features:
        features.remove("per_object_debug_info")

    enable_per_object_debug_info = attr.per_object_debug_info
    if enable_per_object_debug_info:
        features.append("per_object_debug_info")

    compilation_mode = settings["//command_line_option:compilation_mode"]
    if attr.override_compilation_mode:
        compilation_mode = attr.override_compilation_mode

    return {
        "//command_line_option:compilation_mode": compilation_mode,
        "//command_line_option:fission": attr.fission,
        "//command_line_option:features": features,
    }

fission_transition = transition(
    implementation = _fission_transition_impl,
    inputs = [
        "//command_line_option:compilation_mode",
        "//command_line_option:features",
    ],
    outputs = [
        "//command_line_option:compilation_mode",
        "//command_line_option:features",
        "//command_line_option:fission",
    ],
)

def _dwp_file_impl(ctx):
    file = ctx.attr.name
    file = ctx.actions.declare_file(file)
    ctx.actions.symlink(
        output = file,
        target_file = ctx.attr.src[0][DebugPackageInfo].dwp_file,
    )

    return [DefaultInfo(files = depset([file]))]

dwp_file = rule(
    implementation = _dwp_file_impl,
    attrs = {
        "src": attr.label(
            cfg = fission_transition,
            mandatory = True,
            doc = "The actual target to build and grab the .dwp file from.",
            providers = [DebugPackageInfo],
        ),
        # NOTE: we should eventually be able to remove this (see #109).
        "per_object_debug_info": attr.bool(
            default = True,
        ),
        "fission": attr.string(
            default = "yes",
            values = ["yes", "no", "dbg", "fastbuild", "opt"],
        ),
        # NOTE: this should eventually not be necessary; see #109 for context
        # and also:
        #   - https://reviews.llvm.org/D80391
        #   - https://github.com/bazelbuild/bazel/issues/14038
        #   - https://github.com/bazelbuild/rules_cc/pull/115
        #
        # Essentially, we now need to specify `-g2` explicitly to generate
        # `.dwo` files.
        "override_compilation_mode": attr.string(
            default = "",
            mandatory = False,
            values = ["dbg", "fastbuild", "opt"],
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)

def _transition_to_platform_transition_impl(_, attr):
    return {"//command_line_option:platforms": str(attr.platform)}

_transition_to_platform_transition = transition(
    implementation = _transition_to_platform_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _transition_library_to_platform_impl(ctx):
    return [
        ctx.attr.lib[0][CcInfo],
    ]

transition_library_to_platform = rule(
    implementation = _transition_library_to_platform_impl,
    attrs = {
        "lib": attr.label(mandatory = True, cfg = _transition_to_platform_transition),
        "platform": attr.label(mandatory = True),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)

def _transition_binary_to_platform_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.name)
    ctx.actions.symlink(output = out, target_file = ctx.file.bin)
    return DefaultInfo(files = depset([out]))

transition_binary_to_platform = rule(
    implementation = _transition_binary_to_platform_impl,
    attrs = {
        "bin": attr.label(
            mandatory = True,
            allow_single_file = True,
            cfg = _transition_to_platform_transition,
        ),
        "platform": attr.label(mandatory = True),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)

_FEATURES = "//command_line_option:features"

def _sanitizer_transition_impl(settings, attr):
    # Enable the requested sanitizer via `--features`, matching how sanitizers
    # are turned on in normal builds (rules_cc's stock asan/ubsan/tsan
    # features). Using a feature means Bazel resets it to `--host_features` in
    # the exec configuration, so build tools stay uninstrumented.
    features = [f for f in settings[_FEATURES] if f != attr.sanitizer]
    return {_FEATURES: features + [attr.sanitizer]}

_sanitizer_transition = transition(
    implementation = _sanitizer_transition_impl,
    inputs = [_FEATURES],
    outputs = [_FEATURES],
)

def _sanitizer_test_impl(ctx):
    # Re-expose the (sanitizer-enabled) binary as this test's executable.
    exe = ctx.attr.src[0][DefaultInfo].files_to_run.executable
    out = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(output = out, target_file = exe, is_executable = True)
    return [DefaultInfo(
        executable = out,
        runfiles = ctx.attr.src[0][DefaultInfo].default_runfiles,
    )]

# Builds and runs `src` with a single sanitizer enabled via `--features`,
# exercising the sanitizer compile/link flags and runtime end to end. Used for
# asan/ubsan/tsan (msan needs an instrumented libc++).
sanitizer_test = rule(
    implementation = _sanitizer_test_impl,
    test = True,
    attrs = {
        "src": attr.label(mandatory = True, cfg = _sanitizer_transition),
        "sanitizer": attr.string(mandatory = True, values = ["asan", "ubsan", "tsan"]),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
)

def _msan_flags_test_impl(ctx):
    env = analysistest.begin(ctx)
    cpp_actions = [
        a
        for a in analysistest.target_actions(env)
        if a.mnemonic == "CppCompile"
    ]
    asserts.true(env, len(cpp_actions) > 0, "expected a CppCompile action")
    argv = cpp_actions[0].argv
    asserts.true(
        env,
        "-fsanitize=memory" in argv,
        "expected -fsanitize=memory on the compile command line, got: %s" % argv,
    )
    asserts.true(
        env,
        [a for a in argv if "libcxx-msan" in a],
        "expected the instrumented libc++ include path on the compile command line, got: %s" % argv,
    )
    return analysistest.end(env)

# Analysis-only test: verifies the msan flags and instrumented-libc++ include
# path are wired into the C++ compile action. This does not link or run, so it
# does not require an actual instrumented libc++ build. msan is enabled through
# the `msan` cc_feature (--features=msan), so it is reset in the exec
# configuration and build tools stay uninstrumented.
msan_flags_test = analysistest.make(
    _msan_flags_test_impl,
    config_settings = {
        "//command_line_option:features": ["msan"],
    },
)

def _stdlib_flags_test_impl(ctx):
    env = analysistest.begin(ctx)
    cpp_actions = [
        a
        for a in analysistest.target_actions(env)
        if a.mnemonic == "CppCompile"
    ]
    asserts.true(env, len(cpp_actions) > 0, "expected a CppCompile action")
    argv = cpp_actions[0].argv

    # The libc++ headers are located explicitly via -nostdinc++ plus
    # -cxx-isystem entries (see _cxx_isystem in cc_toolchain_config.bzl).
    asserts.true(
        env,
        "-nostdinc++" in argv,
        "expected -nostdinc++ on the compile command line, got: %s" % argv,
    )

    # Because -nostdinc++ overrides the C++ header search, -stdlib=libc++ has no
    # compile-time effect and must NOT be passed: clang would report it unused,
    # printing -Wunused-command-line-argument on every object file. Guards the
    # regression fixed by dropping -stdlib=libc++ from the libc++ branches.
    asserts.true(
        env,
        "-stdlib=libc++" not in argv,
        "-stdlib=libc++ must not be on the compile command line (it is unused " +
        "under -nostdinc++ and warns), got: %s" % argv,
    )
    return analysistest.end(env)

# Analysis-only test: with the default builtin-libc++ toolchain, the C++ compile
# action must locate libc++ via -nostdinc++/-cxx-isystem and must not carry a
# redundant -stdlib=libc++ (which triggers -Wunused-command-line-argument). Runs
# on Linux and macOS (builtin-libc++ emits -nostdinc++ on both).
stdlib_flags_test = analysistest.make(_stdlib_flags_test_impl)
