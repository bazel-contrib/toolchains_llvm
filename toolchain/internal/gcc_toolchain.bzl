load(
    "//toolchain/internal:common.bzl",
    _canonical_dir_path = "canonical_dir_path",
    _is_absolute_path = "is_absolute_path",
    _os_arch_pair = "os_arch_pair",
    _pkg_name_from_label = "pkg_name_from_label",
    _pkg_path_from_label = "pkg_path_from_label",
    _supported_targets = "SUPPORTED_TARGETS",
)

def _gcc_toolchain_path(gcc_toolchain_dict, os, arch):
    gcc_toolchain = gcc_toolchain_dict.get(_os_arch_pair(os, arch), gcc_toolchain_dict.get(""))
    if not gcc_toolchain:
        return (None, None)

    if _is_absolute_path(gcc_toolchain):
        return (gcc_toolchain, None)

    label = Label(gcc_toolchain)
    gcc_toolchain_path = _pkg_path_from_label(label)
    return (gcc_toolchain_path, label)

def gcc_toolchain_paths_dict(rctx, gcc_toolchain_dict, use_absolute_paths):
    paths_dict = dict()
    labels_dict = dict()
    for (target_os, target_arch) in _supported_targets:
        path, label = _gcc_toolchain_path(
            gcc_toolchain_dict,
            target_os,
            target_arch,
        )
        if not path:
            continue

        if label and use_absolute_paths:
            label = Label(_pkg_name_from_label(label) + ":BUILD.bazel")
            path = _canonical_dir_path(str(rctx.path(label).dirname))
            label = None

        target_pair = _os_arch_pair(target_os, target_arch)
        paths_dict[target_pair] = path
        labels_dict[target_pair] = label

    return paths_dict, labels_dict
