"""Version-gated C++ modules smoke-test targets."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@rules_cc//cc:defs.bzl", "cc_library", "cc_test")

def cpp_modules_tests():
    """Defines module targets only where cc_library supports their attributes."""
    if not bazel_features.cc.cc_toolchain_has_generate_modmap:
        return

    cc_library(
        name = "cpp20_module",
        module_interfaces = ["cpp20_module.cppm"],
    )

    cc_test(
        name = "cpp20_module_test",
        size = "small",
        srcs = ["cpp20_module_test.cc"],
        deps = [":cpp20_module"],
    )
