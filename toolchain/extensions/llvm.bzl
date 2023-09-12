"""LLVM extension for use with bzlmod"""

load("@llvm_toolchain//toolchain:rules.bzl", "llvm_toolchain")
load(
    "@llvm_toolchain//toolchain/internal:repo.bzl",
    _llvm_config_attrs = "llvm_config_attrs",
    _llvm_repo_attrs = "llvm_repo_attrs",
)

def _llvm_impl_(module_ctx):
    for mod in module_ctx.modules:
        if not mod.is_root:
            fail("Only the root module can use the 'llvm' extension")
        for toolchain_attr in mod.tags.toolchain:
            llvm_toolchain(
                name = toolchain_attr.name,
                llvm_version = toolchain_attr.llvm_version,
                llvm_versions = toolchain_attr.llvm_versions,
                stdlib = toolchain_attr.stdlib,
                sha256 = toolchain_attr.sha256,
                strip_prefix = toolchain_attr.strip_prefix,
                urls = toolchain_attr.urls,
            )

_attrs = {
    "name": attr.string(doc = """\
        Base name for generated repositories, allowing more than one mylang toolchain to be registered.
        Overriding the default is only permitted in the root module.
    """, default = "llvm_toolchain"),
}
_attrs.update(_llvm_config_attrs)
_attrs.update(_llvm_repo_attrs)

llvm = module_extension(
    implementation = _llvm_impl_,
    tag_classes = {
        "toolchain": tag_class(
            attrs = _attrs,
        ),
    },
)
