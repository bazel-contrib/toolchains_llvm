"""Some alias rules that transition `--platforms`."""

def _wasm_platform_transition(_settings, _attr):
    return {
        "//command_line_option:platforms":
            str(Label("//tests/extra_targets/wasm:wasm")),
    }

wasm_platform_transition = transition(
    implementation = _wasm_platform_transition,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _wasm_file_impl(ctx):
    wasm_file = ctx.attr.name
    wasm_file = ctx.actions.declare_file(wasm_file)
    ctx.actions.symlink(
        output = wasm_file,
        target_file = ctx.executable.src,
        is_executable = True,
    )

    return [DefaultInfo(files = depset([wasm_file]))]

wasm_file = rule(
    implementation = _wasm_file_impl,
    attrs = {
        "src": attr.label(
            executable = True,
            cfg = wasm_platform_transition,
            mandatory = True,
            doc = "TODO",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
    },
    incompatible_use_toolchain_transition = True,
    doc = "TODO",
)

###############################################################################

def _wasi_platform_transition(_settings, _attr):
    return {
        "//command_line_option:platforms":
            str(Label("//tests/extra_targets/wasm:wasi")),
    }

wasi_platform_transition = transition(
    implementation = _wasi_platform_transition,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _wasi_file_impl(ctx):
    wasi_file = ctx.attr.name
    wasi_file = ctx.actions.declare_file(wasi_file)
    ctx.actions.symlink(
        output = wasi_file,
        target_file = ctx.executable.src,
        is_executable = True,
    )

    return [DefaultInfo(files = depset([wasi_file]))]

wasi_file = rule(
    implementation = _wasi_file_impl,
    attrs = {
        "src": attr.label(
            executable = True,
            cfg = wasi_platform_transition,
            mandatory = True,
            doc = "TODO",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist"
        ),
    },
    incompatible_use_toolchain_transition = True,
    doc = "TODO",
)
