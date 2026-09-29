"""LLVM extension for use with bzlmod"""

load("@bazel_features//:features.bzl", "bazel_features")
load("@toolchains_llvm//toolchain:rules.bzl", "llvm_toolchain")
load(
    "@toolchains_llvm//toolchain/internal:repo.bzl",
    _llvm_config_attrs = "llvm_config_attrs",
    _llvm_repo_attrs = "llvm_repo_attrs",
)
load(
    "//toolchain/internal:common.bzl",
    _is_absolute_path = "is_absolute_path",
)

def _root_dict(roots, cls, name, strip_target):
    res = {}
    for root in roots:
        targets = list(root.targets)
        if not targets:
            targets = [""]
        for target in targets:
            if res.get(target):
                fail("duplicate target '%s' found for %s with name '%s'" % (target, cls, name))
            path = getattr(root, "path", "")
            if bool(path) == bool(root.label):
                fail("target '%s' for %s with name '%s' must have either path or label, but not both" % (target, cls, name))
            if path:
                if not _is_absolute_path(path):
                    fail("target '%s' for %s with name '%s' must have an absolute path value" % (target, cls, name))
                res.update([(target, path)])
                continue
            label_str = str(root.label)
            if strip_target:
                label_str = label_str.split(":")[0]
            res.update([(target, label_str)])

    return res

def _constraint_dict(tags, name):
    constraints = {}

    # Gather all the additional constraints for each target
    for tag in tags:
        targets = list(tag.targets)
        if not targets:
            targets = [""]
        for target in targets:
            constraints_for_target = constraints.setdefault(target, [])
            constraints_for_target.extend([str(c) for c in tag.constraints])

    return constraints

def _llvm_impl_(module_ctx):
    for mod in module_ctx.modules:
        toolchain_names = []
        for toolchain_attr in mod.tags.toolchain:
            if not mod.is_root:
                fail("Only the root module can use the 'llvm.toolchain()' tag")
            name = toolchain_attr.name
            toolchain_names.append(name)
            attrs = {
                key: getattr(toolchain_attr, key)
                for key in dir(toolchain_attr)
                if not key.startswith("_")
            }
            attrs["toolchain_roots"] = _root_dict([root for root in mod.tags.toolchain_root if root.name == name], "toolchain_root", name, True)
            attrs["target_toolchain_roots"] = _root_dict([root for root in mod.tags.target_toolchain_root if root.name == name], "target_toolchain_root", name, True)
            attrs["sysroot"] = _root_dict([sysroot for sysroot in mod.tags.sysroot if sysroot.name == name], "sysroot", name, False)
            attrs["extra_compiler_files_dict"] = _root_dict([tag for tag in mod.tags.extra_compiler_files if tag.name == name], "extra_compiler_files", name, False)
            attrs["extra_linker_files_dict"] = _root_dict([tag for tag in mod.tags.extra_linker_files if tag.name == name], "extra_linker_files", name, False)
            attrs["extra_exec_compatible_with"] = _constraint_dict(
                [tag for tag in mod.tags.extra_exec_compatible_with if tag.name == name],
                name,
            )
            attrs["extra_target_compatible_with"] = _constraint_dict(
                [tag for tag in mod.tags.extra_target_compatible_with if tag.name == name],
                name,
            )

            llvm_toolchain(
                **attrs
            )

        # Check that every defined toolchain_root or sysroot has a corresponding toolchain.
        for root in mod.tags.toolchain_root:
            if root.name not in toolchain_names:
                fail("toolchain_root '%s' does not have a corresponding toolchain" % root.name)
        for root in mod.tags.target_toolchain_root:
            if root.name not in toolchain_names:
                fail("target_toolchain_root '%s' does not have a corresponding toolchain" % root.name)
        for root in mod.tags.sysroot:
            if root.name not in toolchain_names:
                fail("sysroot '%s' does not have a corresponding toolchain" % root.name)
        for tag in mod.tags.extra_compiler_files:
            if tag.name not in toolchain_names:
                fail("extra_compiler_files '%s' does not have a corresponding toolchain" % tag.name)
        for tag in mod.tags.extra_linker_files:
            if tag.name not in toolchain_names:
                fail("extra_linker_files '%s' does not have a corresponding toolchain" % tag.name)

    if bazel_features.external_deps.extension_metadata_has_reproducible:
        return module_ctx.extension_metadata(reproducible = True)
    else:
        return None

_attrs = {
    "name": attr.string(doc = """\
        Base name for the generated repositories, allowing more than one LLVM toolchain to be registered.
    """, default = "llvm_toolchain"),
}
_attrs.update(_llvm_config_attrs)
_attrs.update(_llvm_repo_attrs)

_attrs.pop("toolchain_roots", None)
_attrs.pop("target_toolchain_roots", None)
_attrs.pop("sysroot", None)
_attrs.pop("extra_compiler_files_dict", None)
_attrs.pop("extra_linker_files_dict", None)

llvm = module_extension(
    implementation = _llvm_impl_,
    tag_classes = {
        "toolchain": tag_class(
            attrs = _attrs,
        ),
        "toolchain_root": tag_class(
            doc = """\
Selects the LLVM distribution (the "toolchain root") used for the build's
*exec* configuration, i.e. the clang/lld binaries that actually run.

This is the bzlmod equivalent of the `toolchain_roots` attribute of the
`llvm_toolchain` repository rule. Specify the root with exactly one of
`label` or `path`:

- `label`: a label whose *package* is the toolchain root. The label target
  itself is not used; only its package path is read (e.g.
  `@llvm_toolchain_llvm//:BUILD`). Use this for a toolchain vendored into a
  Bazel repository, laid out like `@toolchains_llvm//toolchain:BUILD.llvm_repo`.
- `path`: an absolute path to a system install of LLVM. Setting a `path`
  configures the toolchain to use absolute paths.

Use the `targets` attribute to scope a root to specific host OS/arch pairs;
an empty `targets` list applies to all. Emit one tag per distinct root.
""",
            attrs = {
                "name": attr.string(doc = "Must match the `name` of the corresponding `toolchain` tag.", default = "llvm_toolchain"),
                "targets": attr.string_list(doc = "Host OS/arch pairs this root applies to (e.g. `linux-x86_64`); an empty list applies to all."),
                "label": attr.label(doc = "Label whose package path is the toolchain root package. Mutually exclusive with `path`."),
                "path": attr.string(doc = "Absolute path to a system LLVM distribution to use as the toolchain root. Mutually exclusive with `label`."),
            },
        ),
        "target_toolchain_root": tag_class(
            doc = """\
Selects the LLVM distribution (the "toolchain root") used for the build's
*target* configuration when cross-compiling, i.e. the libraries and headers
that get linked into the produced binaries.

This is the bzlmod equivalent of the `target_toolchain_roots` attribute of
the `llvm_toolchain` repository rule, and the per-target counterpart of the
`toolchain_root` tag. When unset for a given target, the toolchain falls
back to the (exec) `toolchain_root`, which is the common single-distribution
case. Set this when the target needs a different LLVM distribution than the
exec tools, e.g. a target-arch build of libc++/compiler-rt.

Specify the root with `label`, which points at the *package* holding a
`BUILD.llvm_repo`-style layout. Use `targets` to scope to specific target
OS/arch pairs; an empty list applies to all.
""",
            attrs = {
                "name": attr.string(doc = "Must match the `name` of the corresponding `toolchain` tag.", default = "llvm_toolchain"),
                "targets": attr.string_list(doc = "Target OS/arch pairs this root applies to (e.g. `linux-aarch64`); an empty list applies to all."),
                "label": attr.label(doc = "Label whose package path is the target toolchain root package."),
            },
        ),
        "sysroot": tag_class(
            attrs = {
                "name": attr.string(doc = "Same name as the toolchain tag.", default = "llvm_toolchain"),
                "targets": attr.string_list(doc = "Specific targets, if any; empty list means this applies to all."),
                "label": attr.label(doc = "Label containing the files with its package path as the sysroot path."),
                "path": attr.string(doc = "Absolute path to the sysroot."),
            },
        ),
        "extra_compiler_files": tag_class(
            attrs = {
                "name": attr.string(doc = "Same name as the toolchain tag.", default = "llvm_toolchain"),
                "targets": attr.string_list(doc = "Specific targets, if any; empty list means this applies to all."),
                "label": attr.label(doc = "Label containing files to be made available in the sandbox for compile actions."),
            },
        ),
        "extra_linker_files": tag_class(
            attrs = {
                "name": attr.string(doc = "Same name as the toolchain tag.", default = "llvm_toolchain"),
                "targets": attr.string_list(doc = "Specific targets, if any; empty list means this applies to all."),
                "label": attr.label(doc = "Label containing files to be made available in the sandbox for link actions."),
            },
        ),
        "extra_exec_compatible_with": tag_class(
            attrs = {
                "name": attr.string(doc = "Same name as the toolchain tag.", default = "llvm_toolchain"),
                "targets": attr.string_list(doc = "Specific targets, if any; empty list means this applies to all."),
                "constraints": attr.label_list(doc = "List of extra constraints to add to exec_compatible_with for the generated toolchains."),
            },
        ),
        "extra_target_compatible_with": tag_class(
            attrs = {
                "name": attr.string(doc = "Same name as the toolchain tag.", default = "llvm_toolchain"),
                "targets": attr.string_list(doc = "Specific targets, if any; empty list means this applies to all."),
                "constraints": attr.label_list(doc = "List of extra constraints to add to target_compatible_with for the generated toolchains."),
            },
        ),
    },
)
