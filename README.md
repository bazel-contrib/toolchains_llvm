# LLVM toolchain for Bazel [![Tests](https://github.com/bazel-contrib/toolchains_llvm/actions/workflows/tests.yml/badge.svg)](https://github.com/bazel-contrib/toolchains_llvm/actions/workflows/tests.yml)

## Quickstart

See notes on the [release](https://github.com/bazel-contrib/toolchains_llvm/releases)
for how to get started.

NOTE: For releases prior to 0.10.1, please also see [these notes](REPO_RENAME.md).

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

Each toolchains_llvm release contains a snapshot of the LLVM distributions
known when it was published. You do not have to wait for another
toolchains_llvm release to use a newer LLVM release, an LLVM prerelease, or a
custom build. Add its archive names and SHA-256s to
`extra_llvm_distributions`, then select the version normally with
`llvm_version`.

For an official LLVM release that is not in the bundled table, archive
basenames are sufficient: the standard LLVM GitHub release URL is inferred.
The required SHA-256s can be obtained with
`utils/extra_distributions.sh -v <version>` (see
[Distribution data and scripts](#distribution-data-and-scripts) below):

```starlark
llvm = use_extension("@toolchains_llvm//toolchain/extensions:llvm.bzl", "llvm", dev_dependency = True)
llvm.toolchain(
    name = "llvm_toolchain",
    llvm_version = "20.1.4",
    extra_llvm_distributions = {
        "LLVM-20.1.4-Linux-ARM64.tar.xz": "4de80a332eecb06bf55097fd3280e1c69ed80f222e5bdd556221a6ceee02721a",
        "LLVM-20.1.4-Linux-X64.tar.xz": "113b54c397adb2039fa45e38dc8107b9ec5a0baead3a3bac8ccfbb65b2340caa",
        "LLVM-20.1.4-macOS-ARM64.tar.xz": "debb43b7b364c5cf864260d84ba1b201d49b6460fe84b76eaa65688dfadf19d2",
        "clang+llvm-20.1.4-x86_64-pc-windows-msvc.tar.xz": "2b12ac1a0689e29a38a7c98c409cbfa83f390aea30c60b7a06e4ed73f82d2457",
    },
)
```

The same mechanism works for a prerelease that is newer than the distribution
snapshot. For example, the following configuration made 23.1.0-rc3 available
before it was bundled with toolchains_llvm:

```starlark
llvm.toolchain(
    name = "llvm_toolchain",
    llvm_version = "23.1.0-rc3",
    extra_llvm_distributions = {
        "LLVM-23.1.0-rc3-Linux-ARM64.tar.xz": "02165e7811fcc015502f7be30f5887db0c8904947b3c620af4236e15f1669431",
        "LLVM-23.1.0-rc3-Linux-X64.tar.xz": "76ec17df0b0401d9427dbaf6403c2dfc5b5daeda1553566def4139418a35f1",
        "LLVM-23.1.0-rc3-macOS-ARM64.tar.xz": "d23dc0baf29225e2975447f29bbc98b4fc3779001e91adc4a5d7d95854681e79",
    },
)
```

Prereleases must be requested explicitly. Following the common SemVer range
convention, they are excluded from `latest`, `first`, and stable-only version
requirements. An exact `llvm_version = "23.1.0-rc3"` selects that release, and
a requirement opts in by naming a prerelease with the same
major/minor/patch tuple. Thus `latest:>=23.1.0-rc1` can select `23.1.0-rc3`,
while `latest:>=23` and `latest:>22` cannot select it.

`extra_llvm_distributions` is not limited to official LLVM artifacts. Its keys
may also be complete download URLs or absolute local paths, so internally
built, repackaged, or third-party LLVM distributions can be registered
directly. Alternatively, keep basename keys and use
`alternative_llvm_sources` to provide one or more mirror URL templates. In
either case, use the usual `LLVM-<version>-...` or
`clang+llvm-<version>-...` archive naming so version and host-platform
selection can recognize the distribution. An asset is usable for a requested
version only when its filename contains that logical version; LLVM
occasionally publishes platform assets under a different product version.

By default, extra distributions are merged with the bundled table. An extra
entry with the same basename replaces the bundled checksum; use a complete URL
or local path as the key to replace its source as well. When equivalent
compression variants coexist, `.tar.zst` is preferred over `.tar.xz` and
`.tar.gz`.

Set `use_builtin_llvm_distributions = False` only when the bundled distribution
table must be ignored completely. It removes all bundled checksums and URLs
from version and host-platform selection; the toolchain can then select only
artifacts supplied through `extra_llvm_distributions` or
`extra_llvm_distribution_files`. This is useful for patched releases that
retain an upstream version, private allowlists, or configurations that must use
only explicitly declared artifacts. It is not needed merely to add a newer
release or prerelease. At least one matching extra distribution must be
provided when this option is disabled.

Downstream maintainers who patch or vendor toolchains_llvm itself can instead
put persistent bundle additions in
[`toolchain/distributions/extra.jsonc`](toolchain/distributions/extra.jsonc).
That file is intentionally empty upstream and is loaded after
`pre_github.jsonc`, `github_legacy.jsonc`, and `github.jsonc`, so an identical
key replaces the earlier checksum. Its `_meta.base_url` can also redirect the
entries it contains to a downstream release server. The file can be changed
in a fork or patched into the module with `single_version_override` or
`archive_override`. Unlike the `extra_llvm_distributions` attribute, which is
scoped to one toolchain declaration, `extra.jsonc` changes the bundled table
for every consumer of that patched toolchains_llvm source.

A workspace can keep its distributions in independent JSON or JSONC files
without patching toolchains_llvm. Export the files from a Bazel package and
pass their labels through `extra_llvm_distribution_files`:

```starlark
# config/BUILD.bazel
exports_files(["llvm_distributions.jsonc"])
```

```starlark
# MODULE.bazel
llvm.toolchain(
    name = "llvm_toolchain",
    llvm_version = "22.1.8",
    use_builtin_llvm_distributions = False,
    extra_llvm_distribution_files = [
        "//config:llvm_distributions.jsonc",
    ],
)
```

Here `use_builtin_llvm_distributions = False` makes the external file the
complete distribution set rather than an addition to the bundled set. Omit the
attribute when the file should merely extend or override bundled entries.

These files use the same schema as `extra.jsonc` and may also come from
another repository, for example
`@company_toolchains//llvm:distributions.jsonc`. Multiple files are merged in
list order; later files replace earlier checksums and covered URL templates.
The inline `extra_llvm_distributions` dictionary is merged last.

For complete control over the archive selected for each execution platform,
use the lower-level `urls`, `sha256`, and `strip_prefix` attributes instead.

The following `WORKSPACE` snippet shows how to add a specific version for a specific target before
the version was added to the bundled distribution data under
[`toolchain/distributions/`](toolchain/distributions).

```starlark
llvm_toolchain(
    name = "llvm_toolchain",
    llvm_version = "19.1.6",
    sha256 = {"linux-x86_64": "d55dcbb309de7ade4e3073ec3ac3fac4d3ff236d54df3c4de04464fe68bec531"},
    strip_prefix = {
        "linux-x86_64": "LLVM-19.1.6-Linux-X64",
    },
    urls = {
        "linux-x86_64": [
            "https://github.com/llvm/llvm-project/releases/download/llvmorg-19.1.6/LLVM-19.1.6-Linux-X64.tar.xz",
        ],
    },
)
```

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

### Requirements

Version attributes can be requirements of the form `first`, `first:<condition>`,
`latest` or `latest:<condition>`.

In case of `latest`, the latest distribution matching the optional `condition`
will be selected.

In case of `first`, the first distribution matching the optional `condition`
will be selected.

The condition consists of a comma separated list of semver version comparisons
supporting `<`, `<=`, `>`, `>=`, `==`, `!=`. Examples:

- `latest`
- `latest:>=20.1.0`
- `latest:>17.0.4,!=19.1.7,<=20.1.0`
- `first:>=15.0.6,<16`

It is further possible to provide the version or requirement from an environment
variable with a fallback version or requirement. In this case it is important to
also use the bazel flag `--repo_env=LLVM_VERSION=version_or_requirement`. It is
important to use both correctly because otherwise the resulting builds are not
reproducible. The main purpose of using an environment variable to encode the
version for integration or batch testing on multiple platforms where multiple
LLVM versions should be tested.

- `getenv(ENVIRONMENT_VARIABLE_NAME,fallback)`

Example `MODULE.bazel`

```starlark
llvm.toolchain(
    name = "llvm_toolchain",
    llvm_versions = {
        "": "getenv(LLVM_VERSION,latest:>=17.0.0,<20)",
        "darwin-x86_64": "15.0.7",  # Verify this works as opposed to using one version.
    },
)
```

In this example, MacOS x86 machines have their LLVM version hard-coded to
`15.0.7`. For all other targets the LLVM version is read from the environment
variable `LLVM_VERSION` which must be referenced on the Bazel command line as
explained above. If the variable is not present, then the LLVM version defaults
to the requirement expression `latest:>=17.0.0,<20`.

### Selecting Toolchains

If toolchains are registered (see Quickstart section above), you do not need to
do anything special for bazel to find the toolchain. You may want to check once
with the `--toolchain_resolution_debug` flag to see which toolchains were
selected by bazel for your target platform.

For specifying unregistered toolchains on the command line, please use the
`--extra_toolchains` flag. For example,
`--extra_toolchains=@llvm_toolchain//:cc-toolchain-x86_64-linux`.

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
   for each host os-arch pair through the `toolchain_roots` attribute (without
   bzlmod) or the `toolchain_root` module extension tags (with bzlmod). Note
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

A sysroot can be specified through the `sysroot` attribute (without bzlmod) or
the `sysroot` module extension tag (with bzlmod). This can be either a path on
the user's system, or a bazel `filegroup` like label. One way to create a
sysroot is to use `docker export` to get a single archive of the entire
filesystem for the image you want. Another way is to use the build scripts
provided by the [Chromium
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
and the target platform. For example, see the [MODULE.bazel](tests/MODULE.bazel)
file for `llvm_toolchain_with_sysroot` and the [test
script](tests/scripts/run_xcompile_tests.sh) for cross-compilation.

```sh
bazel build \
  --platforms=@toolchains_llvm//platforms:linux-x86_64 \
  --extra_toolchains=@llvm_toolchain_with_sysroot//:cc-toolchain-x86_64-linux \
  //...
```

#### Per-target toolchain root

By default a single LLVM distribution (the "toolchain root") provides both the
clang/lld binaries that run (the _exec_ configuration) and the libraries that
get linked into the produced binaries (the _target_ configuration). When the
target needs a different distribution than the exec tools (for example a
target-arch build of libc++ or compiler-rt), specify it separately through the
`target_toolchain_roots` attribute (without bzlmod) or the
`target_toolchain_root` module extension tag (with bzlmod). It is the
per-target counterpart of `toolchain_roots` / `toolchain_root`, and falls back
to the exec toolchain root when unset.

#### libstdc++ and Yocto sysroot layouts

When linking against libstdc++ from a sysroot, three attributes (each keyed by
target OS/arch pair) tune how it is found and linked:

- `stdlib`: in addition to the values described under
  [Sysroots](#sysroots), `dynamic-stdc++` (optionally `dynamic-stdc++-<ver>`)
  behaves like `stdc++` but links `libstdc++.so` instead of the default static
  `libstdc++.a`.
- `multiarch`: overrides the multiarch tuple used to construct the sysroot
  include and library paths. Useful when the sysroot uses a non-standard tuple,
  e.g. Yocto's `aarch64-oe4t-linux`.
- `cxx_include_layout`: selects how libstdc++ headers and the gcc runtime libs
  are laid out in the sysroot. `debian` (the default) expects
  `/usr/include/<multiarch>/c++/<ver>` and `/usr/lib/gcc/<multiarch>/<ver>`;
  `yocto` expects `/usr/include/c++/<ver>/<multiarch>` and
  `/usr/lib/<multiarch>/<ver>`.

All three are optional: omit them to get static libstdc++ linking, the builtin
multiarch tuple, and the `debian` layout.

### Multi-platform builds

The toolchain supports multi-platform builds through the combination of the
`exec_os`, `exec_arch` attribute pair, and either the `distribution` attribute,
or the `urls` attribute. This allows one to run their builds on one platform
(e.g. macOS) and their build actions to run on another (e.g. Linux), enabling
remote build execution (RBE). For example, see the [MODULE.bazel](tests/MODULE.bazel)
file for `llvm_toolchain_linux_exec` and the [test
script](tests/scripts/run_docker_exec_test.sh) for running the build actions on
Linux even if the build is being run from macOS.

```sh
bazel build \
  --platforms=@toolchains_llvm//platforms:linux-x86_64 \
  --extra_execution_platforms=@toolchains_llvm//platforms:linux-x86_64 \
  --extra_toolchains=@llvm_toolchain_linux_exec//:cc-toolchain-x86_64-linux \
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
deps (also known as "depend on what you use") for `cc_*` rules. This feature
can be enabled by enabling the `layering_check` feature on a per-target,
per-package or global basis.

### Sanitizers

The toolchain can build with AddressSanitizer, UndefinedBehaviorSanitizer,
ThreadSanitizer, or MemorySanitizer. Enable at most one at a time, via Bazel
features:

```sh
bazel build //... --features=asan
bazel build //... --features=ubsan
bazel build //... --features=tsan
bazel build //... --features=msan   # Linux only; see below
```

`asan`, `ubsan`, and `tsan` are rules_cc's stock sanitizer features and work
with the regular standard library. Enabling sanitizers as features means Bazel
resets them to `--host_features` in the exec configuration, so build tools stay
uninstrumented. For finer-grained control, combine with
`--copt=-fsanitize-ignorelist=...` (the provided file is made available to
compile actions via the `extra_compiler_files` attribute).

MemorySanitizer additionally swaps in an instrumented libc++ (see below).

#### MemorySanitizer and the instrumented libc++

MemorySanitizer is Linux-only and is enabled with `--features=msan`. A feature
is used so Bazel resets it to `--host_features` in the exec configuration,
keeping build tools uninstrumented.

MemorySanitizer reports false positives unless the C++ standard library is also
instrumented, so `msan` swaps the toolchain's libc++ for an instrumented build
(headers under `libcxx-msan/include`, libraries under `libcxx-msan/lib`).
There is no official prebuilt instrumented libc++; you must build one from the
matching LLVM sources and point the distribution at it with the `libcxx_url`
and `libcxx_sha256` attributes (`llvm`/`llvm_toolchain` rules, or the
`llvm.toolchain` module extension tag):

```python
llvm(
    name = "llvm_toolchain_llvm",
    llvm_version = "20.1.0",
    libcxx_url = "https://example.com/libcxx-msan-20.1.0-x86_64-linux-gnu.tar.zst",
    libcxx_sha256 = "<sha256>",
)
```

Build the instrumented libc++ following the [MemorySanitizer libc++
how-to](https://github.com/google/sanitizers/wiki/MemorySanitizerLibcxxHowTo),
e.g.:

```sh
cmake -GNinja <llvm-src>/runtimes \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
  -DLLVM_USE_SANITIZER=MemoryWithOrigins \
  -DLLVM_ENABLE_PIC=ON \
  -DCMAKE_INSTALL_PREFIX=<prefix>
ninja && ninja install
# Archive the resulting <prefix>/lib and <prefix>/include directories; that is
# the layout extracted into libcxx-msan/. libunwind itself is too low-level to
# instrument, so overwrite the instrumented libunwind.* with the uninstrumented
# one from your clang distribution before archiving.
```

## Distribution data and scripts

The list of LLVM releases this toolchain knows about lives as JSONC data
under [`toolchain/distributions/`](toolchain/distributions). A repository
rule merges every JSONC file into a single lookup table at module-load time:

| file                                                                 | role                                                                                                                                       |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| [`pre_github.jsonc`](toolchain/distributions/pre_github.jsonc)       | LLVM 6.x–9.x hosted on releases.llvm.org. Hand-maintained, frozen.                                                                         |
| [`github_legacy.jsonc`](toolchain/distributions/github_legacy.jsonc) | LLVM 10.x–18.x with pre-19.x irregular naming. Hand-maintained, frozen.                                                                    |
| [`github.jsonc`](toolchain/distributions/github.jsonc)               | LLVM 19.x and newer. Regenerated end-to-end by `utils/update_distributions.sh`.                                                            |
| [`extra.jsonc`](toolchain/distributions/extra.jsonc)                 | Empty by default. Downstream slot for additional bundled releases; loaded last, so any key here overrides the same key in the other files. |

Each file has the shape:

```jsonc
{
  "_meta": {
    "description": "...",
    "base_url": {
      "": "https://example.com/llvm-{version}/",
      "<version>": "https://override/{version}/", // optional per-version
    },
  },
  "<tarball-basename>": "<sha256>",
  "<full-url-or-path>": "<sha256>",
}
```

`base_url` is optional. Its `""` key sets a per-file default URL template;
the optional `"<version>"` keys override individual releases. Templates may
contain `{version}` (substituted at materialization time) and should end
with `/` — the basename is appended directly. Files that omit `base_url`
fall back to the standard GitHub release URL
(`https://github.com/llvm/llvm-project/releases/download/llvmorg-{version}/`).

Entry keys are either a tarball **basename** (URL derived via `base_url`)
or a **full URL/path** (used verbatim, bypassing `base_url`). Comments are
stripped before parsing, and trailing commas are tolerated.

LLVM archives compressed as `.tar.zst`, `.tar.xz`, or `.tar.gz` are
supported. When equivalent zstd and xz archives are available, automatic
selection and the helper scripts prefer the much faster-to-extract zstd form.

### Two helper scripts

- **`utils/update_distributions.sh`** — refreshes
  [`toolchain/distributions/github.jsonc`](toolchain/distributions/github.jsonc)
  by paging through the GitHub releases API for `llvm/llvm-project` and
  rewriting the file in place. Use this when contributing a new LLVM release
  to the bundled list. The script also regenerates the test golden file so
  the diff stays self-contained. No tarballs are downloaded — checksums come
  from GitHub's release-asset `.digest` field, with existing values
  preserved for older assets that predate that field. Set `GITHUB_TOKEN` to
  avoid the unauthenticated API rate limit. See `-h` for details.

- **`utils/extra_distributions.sh`** — prints checksums for a single LLVM
  release, formatted to paste straight into the `extra_llvm_distributions`
  attribute shown earlier. Use this only when the version you want is _not
  yet bundled_ in `github.jsonc`; if it is, just bump `llvm_version` and let
  the toolchain pick up the existing entries. Falls back to downloading
  tarballs and computing SHA-256 locally for older assets that don't have a
  `.digest`. See `-h` for details.

Both scripts run on Linux, macOS, and on Windows under Git Bash / MSYS2 /
WSL. They require `bash`, `curl`, `jq`, and `awk`;
`utils/extra_distributions.sh` additionally needs `sha256sum` (Linux, Git
Bash) or `shasum` (macOS).

## Prior Art

Other examples of toolchain configuration:

https://bazel.build/tutorials/ccp-toolchain-config

https://github.com/vsco/bazel-toolchains
