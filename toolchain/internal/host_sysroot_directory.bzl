load("@bazel_skylib//rules/directory:providers.bzl", "create_directory_info")

# Workaround https://github.com/bazelbuild/rules_cc/issues/277

host_sysroot_directory = rule(
    implementation = lambda ctx : create_directory_info(
        path = ctx.attr.path
    ),
    attrs = {
        "path": attr.string(mandatory = True)
    }
)