def _fake_cc_toolchain_config_impl(ctx):
    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        toolchain_identifier = "fake_cc",
        target_system_name = "fake",
        target_cpu = "fake",
        target_libc = "fake",
        compiler = "fake",
    )

fake_cc_toolchain_config = rule(
    implementation = _fake_cc_toolchain_config_impl,
    attrs = {},
    provides = [CcToolchainConfigInfo],
)
