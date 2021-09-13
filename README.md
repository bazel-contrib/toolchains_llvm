LLVM toolchain for Bazel ![Tests](https://github.com/grailbio/bazel-toolchain/workflows/Tests/badge.svg?branch=master) ![Migration](https://github.com/grailbio/bazel-toolchain/workflows/Migration/badge.svg?branch=master)
=================

NOTE: As of 2200d53, this project requires bazel 1.0 or up.

To use this toolchain, include this section in your WORKSPACE:
```python
# Change master to the git tag you want.
http_archive(
    name = "com_grail_bazel_toolchain",
    strip_prefix = "bazel-toolchain-master",
    urls = ["https://github.com/grailbio/bazel-toolchain/archive/master.tar.gz"],
)

load("@com_grail_bazel_toolchain//toolchain:deps.bzl", "bazel_toolchain_dependencies")

bazel_toolchain_dependencies()

load("@com_grail_bazel_toolchain//toolchain:rules.bzl", "llvm_toolchain")

llvm_toolchain(
    name = "llvm_toolchain",
    llvm_version = "8.0.0",
)

load("@llvm_toolchain//:toolchains.bzl", "llvm_register_toolchains")

llvm_register_toolchains()
```

The toolchain can automatically detect your OS type, and use the right
pre-built binary distribution from llvm.org. The detection is currently
based on host OS and is not perfect, so some distributions, docker based
sandboxed builds, and remote execution builds will need toolchains configured
manually through the `distribution` attribute. We expect the detection logic to
grow through community contributions. We welcome PRs! :smile:

See in-code documentation in [rules.bzl](toolchain/rules.bzl) for available
attributes to `llvm_toolchain`.

For making changes to default settings for these toolchains, edit the
cc_toolchain_config template. See [tutorial](
https://github.com/bazelbuild/bazel/blob/master/site/docs/tutorial/cc-toolchain-config.md).

For overriding toolchains on the command line, please use the
`--extra_toolchains` flag in lieu of the deprecated `--crosstool_top` flag.
For example, `--extra_toolchains=@llvm_toolchain//:cc-toolchain-linux`.

Note: you may need to add `build --incompatible_enable_cc_toolchain_resolution`
to your `.bazelrc` to enable toolchain resolution for `cc` toolchains (see
[this][enable-cc-toolchain-res] issue). If you do this, the
`llvm_register_toolchains` call in `WORKSPACE` shown in the example above should
be sufficient to get Bazel to use the toolchain.

[enable-cc-toolchain-res]: https://github.com/bazelbuild/bazel/issues/7260

If you would like to use the older method of selecting toolchains, you can
continue to do so with `--crosstool_top=@llvm_toolchain//:toolchain`.

Notes:

- The LLVM toolchain archive is downloaded and extracted in the named
  repository.  People elsewhere have used wrapper scripts to avoid symlinking
  and get better control of the environment in which the toolchain binaries are
  run.

- A sysroot can be specified through the `sysroot` attribute. This can be either
  a path on the user's system, or a bazel `filegroup` like label. One way to
  create a sysroot is to use `docker export` to get a single archive of the
  entire filesystem for the image you want. Another way is to use the build
  scripts provided by the
  [Chromium project](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/linux_sysroot.md).

- Sandboxing the toolchain introduces a significant overhead (100ms per
  action, as of mid 2018). To overcome this, one can use
  `--experimental_sandbox_base=/dev/shm`.  However, not all environments might
  have enough shared memory available to load all the files in memory. If this
  is a concern, you may set the attribute for using absolute paths, which will
  substitute templated paths to the toolchain as absolute paths. When running
  bazel actions, these paths will be available from inside the sandbox as part of
  the / read-only mount. Note that this will make your builds non-hermetic.

- The toolchain is known to also work with `rules_go`.

- The LLVM toolchain also provides several tools like `clang-format`. You can
  depend on these tools directly in the bin directory of the toolchain. For
  example, `@llvm_toolchain//:bin/clang-format` is a valid and visible target.

## Setting Up Toolchains for Other Targets

### Using `extra_targets`

```starlark
load("@com_grail_bazel_toolchain//toolchain:rules.bzl", "llvm_toolchain")
llvm_toolchain(
    name = "llvm_toolchain",
    llvm_version = "8.0.0",
    extra_targets = [
        "wasm32-unknown-wasi",
    ],

    # Extra targets can have their sysroots overriden too:
    sysroots: {
        "linux": "@some_example_sysroot_repo//:linux_sysroot",
        "darwin": "@some_example_sysroot_repo//:macos_sysroot",

        "linux_wasm32-unknown-wasi": "@some_example_sysroot_repo//:wasi_sysroot",
        "darwin_wasm32-unknown-wasi": "@some_example_sysroot_repo//:wasi_sysroot",
    }
)

load("@llvm_toolchain//:toolchains.bzl", "llvm_register_toolchains")
llvm_register_toolchains()

http_archive(
    name = "some_example_sysroot_repo",
    ...
)
```

The toolchain that is created will have the appropriate constraints so that Bazel
will pick it when resolving a toolchain for a particular platform. For example:

```starlark
platform(
    name = "wasi",
    constraints = [
        "@platforms//os:wasi",
        "@platforms//cpu:wasm32",
    ]
)

cc_library(
    name = "test",
    srcs = [...],
)
```

Running `bazel build //:test --platforms //:wasm` should use the configured
`wasm32-unknown-wasi` toolchain and produce an object file with wasm32 assembly
in it.

Note that this should work also work with rules that apply a
[transition][transition] to require that a target be built for a particular
platform.

[transition]: https://docs.bazel.build/versions/main/skylark/config.html#user-defined-transitions

Also note that the order of the triples in `extra_targets` influences how toolchains will be considered during [toolchain resolution][t-res] as does using a target triple ending with `-unknown` instead of `-none` (as a rule of thumb, prefer `-none` over `-unknown` unless you have a good reason not to). See [this comment][extra-target-pitfalls-comment] for some context.

[t-res]: https://docs.bazel.build/versions/main/toolchains.html#toolchain-resolution
[extra-target-pitfalls-comment]: WORKSPACE#L31-L63

Currently only the `wasm32-unknown-wasi` extra target is fully implemented/tested.
Other targets *can* be specified but are unlikely to work as the glue needed to
fetch their sysroots/compiler-rt (i.e. `libclang_rt.builtins-...`) is not yet
implemented.

### Manually

For other targets (or if you just want to make modifications to the toolchains that the machinery in this repo produces) you can set up a toolchain manually. The process for doing so looks something like this:

```starlark
# WORKSPACE
# (parts to set up `@llvm_toolchain` have been elided; see above)

llvm_toolchain(
    name = "llvm_toolchain",
    llvm_version = "8.0.0",

    # NOTE: This is required to set up toolchains outside of `@llvm_toolchain`, unfortunately
    absolute_paths = True,
 )

# This registers the default toolchains.
load("@llvm_toolchain//:toolchains.bzl", "llvm_register_toolchains", "register_toolchain")

llvm_register_toolchains()

# Now let's make our own:
http_archive(
    name = "thumbv7-sysroot",
    urls = ["example.com"],
)
register_toolchain("//tests:custom_toolchain_example")

# BUILD file:
# Example Custom Toolchain:
load("@llvm_toolchain//:cc_toolchain_config.bzl", "cc_toolchain_config")

# Docs for this function and `overrides` are in `cc_toolchain_config.bzl.tpl`.
cc_toolchain_config(
    name = "custom_toolchain_example_config",
    host_platform = "linux",
    custom_target_triple = "thumbv7em-unknown-none-gnueabihf",
    overrides = {
        "target_system_name": "thumbv7em-unknown-none-gnueabihf",
        "target_cpu": "thumbv7em",
        "target_libc": "unknown",
        "abi_libc_version": "unknown",

        # If you omit this, be sure to depend on
        # `@llvm_toolchain:host_sysroot_components`.
        # "sysroot_path": "external/thumbv7-sysroot/sysroot",

        "extra_compile_flags": [
            "-mthumb",
            "-mcpu=cortex-m4",
            "-mfpu=fpv4-sp-d16",
            "-mfloat-abi=hard",
        ],
        "omit_hosted_linker_flags": True,
        "omit_cxx_stdlib_flag": False,
        "use_llvm_ar_instead_of_libtool_on_macos": True,
    }
)

load("@com_grail_bazel_toolchain//toolchain:rules.bzl", "conditional_cc_toolchain")
conditional_cc_toolchain(
    name = "custom_toolchain",
    toolchain_config = ":custom_toolchain_example_config",
    host_is_darwin = False,

    sysroot_label = "@llvm_toolchain//:host_sysroot_components", # use this if not overriding
    # sysroot_label = "@thumbv7-sysroot//:sysroot", # override

    absolute_paths = True, # this is required for toolchains set up outside of `@llvm_toolchain`, unfortunately
    llvm_repo_label_prefix = "@llvm_toolchain//",
)

# Constraints come from here: https://github.com/bazelbuild/platforms
toolchain(
    name = "custom_toolchain_example",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
    target_compatible_with = [
        "@platforms//cpu:armv7", # `v7e-mf` has not yet made it to stable Bazel?
        # "@platforms//os:none",
    ],
    toolchain = ":custom_toolchain",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)
```

As with the `wasm32-unknown-wasi` example above, you can "use" the toolchain by
creating a platform matching the constraints which the toolchain satisfies and
then either specifying that platform globally (on the command line) or for a
particular target via a transition.

Here's an example of using `target_compatible_with` on a target to get it to
only build when an appropriate target platform is specified:

```starlark
platform(
    name = "arm",
    constraint_values = [
        "@platforms//cpu:armv7",
        # "@platforms//os:none",
    ]
)

cc_library(
    name = "custom_target_test",
    srcs = ["test.cc"],
    target_compatible_with = [
        "@platforms//cpu:armv7",
    ]
)
```

Ultimately the goal is to add support for extra targets directly in this repo;
PRs are very welcome :-).

## Misc

Other examples of toolchain configuration:

https://github.com/bazelbuild/bazel/wiki/Building-with-a-custom-toolchain

https://github.com/vsco/bazel-toolchains
