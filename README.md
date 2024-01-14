# LLVM toolchain for Bazel [![Tests](https://github.com/grailbio/bazel-toolchain/actions/workflows/tests.yml/badge.svg)](https://github.com/grailbio/bazel-toolchain/actions/workflows/tests.yml)

---

The project is in a relatively stable state and in use for all code development
at GRAIL and other organizations. Having said that, I am unable to give time to
it at any regular cadence.

I rely on the community for maintenance and new feature implementations. If you
are interested in being part of this project, please let me know and I can give
you write access, so you can merge your changes directly.

If you feel like you have a better maintained fork or an alternative/derived
implementation, please let me know and I can redirect people there.

– @siddharthab

---

## Quickstart

See notes on the [release](https://github.com/grailbio/bazel-toolchain/releases)
for how to get started.

<!-- Release Notes template is at .github/workflows/release_prep.sh -->

## Basic Usage

The toolchain can automatically detect your OS and arch type, and use the right
pre-built binary LLVM distribution. See the section on "Bring Your Own LLVM"
below for more options.

See in-code documentation in [rules.bzl](toolchain/rules.bzl) for available
attributes to `llvm_toolchain`.

## Advanced Usage

### Per host architecture LLVM version

LLVM does not come with distributions for all host architectures in each
version. In particular patch versions often come with few prebuilt packages.
This means that a single version probably is not enough to address all hosts
one wants to support.

This can be solved by providing a target/version map with a default version.
The example below selects `15.0.6` as the default version for all targets not
specified explicitly. This is like providing `llvm_version = "15.0.6"`, just
like in the example on the top. However, here we provide two more entries that
map their respective target to a distinct version:

```starlark
llvm_toolchain(
    name = "llvm_toolchain",
    llvm_versions = {
        "": "15.0.6",
        "darwin-aarch64": "15.0.7",
        "darwin-x86_64": "15.0.7",
    },
)
```

### Customizations

We currently offer limited customizability through attributes of the
[llvm_toolchain\_\* rules](toolchain/rules.bzl). You can send us a PR to add
more configuration attributes.

A majority of the complexity of this project is to make it generic for multiple
use cases. For one-off experiments with new architectures, cross-compilations,
new compiler features, etc., my advice would be to look at the toolchain
configurations generated by this repo, and copy-paste/edit to make your own in
any package in your own workspace.

```sh
bazel query --output=build @llvm_toolchain//:all | grep -v -e '^#' -e '^  generator'
```

Besides defining your toolchain in your package BUILD file, and until this
[issue](https://github.com/bazelbuild/bazel/issues/7746) is resolved, you would
also need a way for bazel to access the tools in LLVM distribution as relative
paths from your package without using `..` up-references. For this, you can
create a symlink that uses up-references to point to the LLVM distribution
directory, and also create a wrapper script for clang such that the actual
clang invocation is not through the symlinked path. See the files in the
`@llvm_toolchain//:` package as a reference.

```sh
# See generated files for reference.
ls -lR "$(bazel info output_base)/external/llvm_toolchain"

# Create symlink to LLVM distribution.
cd _your_package_directory_
ln -s ../....../external/llvm_toolchain_llvm llvm

# Create CC wrapper script.
mkdir bin
cp "$(bazel info output_base)/external/llvm_toolchain/bin/cc_wrapper.sh" bin/cc_wrapper.sh
vim bin/cc_wrapper.sh # Review to ensure relative paths, etc. are good.
```

See [bazel
tutorial](https://docs.bazel.build/versions/main/tutorial/cc-toolchain-config.html)
for how CC toolchains work in general.

### Selecting Toolchains

If toolchains are registered (see Quickstart section above), you do not need to
do anything special for bazel to find the toolchain. You may want to check once
with the `--toolchain_resolution_debug` flag to see which toolchains were
selected by bazel for your target platform.

For specifying unregistered toolchains on the command line, please use the
`--extra_toolchains` flag. For example,
`--extra_toolchains=@llvm_toolchain//:cc-toolchain-x86_64-linux`.

We no longer support the `--crosstool_top=@llvm_toolchain//:toolchain` flag,
and instead rely on the `--incompatible_enable_cc_toolchain_resolution` flag.

### Bring Your Own LLVM

The following mechanisms are available for using an LLVM toolchain:

1. Host OS information is used to find the right pre-built binary distribution
   from llvm.org, given the `llvm_version` or `llvm_versions` attribute. The
   LLVM toolchain archive is downloaded and extracted as a separate repository
   with the suffix `_llvm`. The detection logic for `llvm_version` is not
   perfect, so you may have to use `llvm_versions` for some host OS type and
   versions. We expect the detection logic to grow through community
   contributions. We welcome PRs.
2. You can use the `urls` attribute to specify your own URLs for each OS type,
   version and architecture. For example, you can specify a different URL for
   Arch Linux and a different one for Ubuntu. Just as with the option above,
   the archive is downloaded and extracted as a separate repository with the
   suffix `_llvm`.
3. You can also specify your own bazel package paths or local absolute paths
   for each host os-arch pair through the `toolchain_roots` attribute. Note
   that the keys here are different and less granular than the keys in the `urls`
   attribute. When using a bazel package path, each of the values is typically
   a package in the user's workspace or configured through `local_repository` or
   `http_archive`; the BUILD file of the package should be similar to
   `@toolchains_llvm//toolchain:BUILD.llvm_repo`. If using only
   `http_archive`, maybe consider using the `urls` attribute instead to get more
   flexibility if you need.
4. All the above options rely on host OS information, and are not suited for
   docker based sandboxed builds or remote execution builds. Such builds will
   need a single distribution version specified through the `distribution`
   attribute, or URLs specified through the `urls` attribute with an empty key, or
   a toolchain root specified through the `toolchain_roots` attribute with an
   empty key.

### Sysroots

A sysroot can be specified through the `sysroot` attribute. This can be either
a path on the user's system, or a bazel `filegroup` like label. One way to
create a sysroot is to use `docker export` to get a single archive of the
entire filesystem for the image you want. Another way is to use the build
scripts provided by the [Chromium
project](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/linux/sysroot.md).

### Cross-compilation

The toolchain supports cross-compilation if you bring your own sysroot. When
cross-compiling, we link against the libstdc++ from the sysroot
(single-platform build behavior is to link against libc++ bundled with LLVM).
The following pairs have been tested to work for some hello-world binaries:

- {linux, x86_64} -> {linux, aarch64}
- {linux, aarch64} -> {linux, x86_64}
- {darwin, x86_64} -> {linux, x86_64}
- {darwin, x86_64} -> {linux, aarch64}

A recommended approach would be to define two toolchains, one without sysroot
for single-platform builds, and one with sysroot for cross-compilation builds.
Then, when cross-compiling, explicitly specify the toolchain with the sysroot
and the target platform. For example, see the [WORKSPACE](tests/WORKSPACE) file and
the [test script](tests/scripts/run_xcompile_tests.sh) for cross-compilation.

```sh
bazel build \
  --platforms=@toolchains_llvm//platforms:linux-x86_64 \
  --extra_toolchains=@llvm_toolchain_with_sysroot//:cc-toolchain-x86_64-linux \
  //...
```

### Supporting New Target Platforms

The following is a rough (untested) list of steps:

1. To help us detect if you are cross-compiling or not, note the arch string as
   given by `python3 -c 'import platform; print(platform.machine())`.
2. Edit `SUPPORTED_TARGETS` in
   [toolchain/internal/common.bzl](toolchain/internal/common.bzl) with the os
   and the arch string from above.
3. Add `target_system_name`, etc. in
   [toolchain/cc_toolchain_config.bzl](toolchain/cc_toolchain_config.bzl).
4. For cross-compiling, add a `platform` bazel type for your target platform in
   [platforms/BUILD.bazel](platforms/BUILD.bazel), and add an appropriate
   sysroot entry to your `llvm_toolchain` repository definition.
5. If not cross-compiling, bring your own LLVM (see section above) through the
   `toolchain_roots` or `urls` attribute.
6. Test your build.

### Sandbox

Sandboxing the toolchain introduces a significant overhead (100ms per action,
as of mid 2018). To overcome this, one can use
`--experimental_sandbox_base=/dev/shm`. However, not all environments might
have enough shared memory available to load all the files in memory. If this is
a concern, you may set the attribute for using absolute paths, which will
substitute templated paths to the toolchain as absolute paths. When running
bazel actions, these paths will be available from inside the sandbox as part of
the / read-only mount. Note that this will make your builds non-hermetic.

### Compatibility

The toolchain is tested to work with `rules_go`, `rules_rust`, and
`rules_foreign_cc`.

### Accessing tools

The LLVM distribution also provides several tools like `clang-format`. You can
depend on these tools directly in the bin directory of the distribution. When
not using the `toolchain_roots` attribute, the distribution is available in the
repo with the suffix `_llvm` appended to the name you used for the
`llvm_toolchain` rule. For example, `@llvm_toolchain_llvm//:bin/clang-format`
is a valid and visible target in the quickstart example above.

When using the `toolchain_roots` attribute, there is currently no single target
that you can reference, and you may have to alias the tools you want with a
`select` clause in your workspace.

As a convenience, some targets are aliased appropriately in the configuration
repo (as opposed to the LLVM distribution repo) for you to use and will work
even when using `toolchain_roots`. The complete list is in the file
[aliases.bzl](toolchain/aliases.bzl). If your repo is named `llvm_toolchain`,
then they can be referenced as:

- `@llvm_toolchain//:omp`
- `@llvm_toolchain//:clang-format`
- `@llvm_toolchain//:llvm-cov`

### Strict header deps (Linux only)

The toolchain supports Bazel's `layering_check` feature, which relies on
[Clang modules](https://clang.llvm.org/docs/Modules.html) to implement strict
deps (also known as "depend on what you use") for `cc_*` rules. This features
can be enabled by enabling the `layering_check` feature on a per-target,
per-package or global basis.

If one of toolchain or sysroot are specified via an absolute path rather than
managed by Bazel, the `layering_check` feature may require running
`bazel clean --expunge` after making changes to the set of header files
installed on the host.

## Prior Art

Other examples of toolchain configuration:

https://bazel.build/tutorials/ccp-toolchain-config

https://github.com/vsco/bazel-toolchains
