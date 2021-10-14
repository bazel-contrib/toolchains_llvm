"""Helper transitions for tests."""

# This transition function sets `--features=per_object_debug_info` and
# `--fission` as well as the compilation mode.
#
# These three Bazel flags influence whether or not `.dwo` and `.dwp` are
# created.
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
    incompatible_use_toolchain_transition = True,
)
