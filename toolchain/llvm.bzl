load(
    "//toolchain/internal:repo.bzl",
    _common_attrs = "common_attrs",
    _llvm_config_attrs = "llvm_config_attrs",
    _llvm_repo_attrs = "llvm_repo_attrs",
    _llvm_repo_impl = "llvm_repo_impl",
)


llvm = repository_rule(
    attrs = _llvm_repo_attrs,
    local = False,
    implementation = _llvm_repo_impl,
)