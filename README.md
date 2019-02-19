LLVM toolchain for Bazel [![Build Status](https://travis-ci.org/grailbio/bazel-toolchain.svg?branch=master)](https://travis-ci.org/grailbio/bazel-toolchain)
=================

To use this toolchain, include this section in your WORKSPACE:
```python
# Change master to the git tag you want.
http_archive(
    name = "com_grail_bazel_toolchain",
    strip_prefix = "bazel-toolchain-master",
    urls = ["https://github.com/grailbio/bazel-toolchain/archive/master.tar.gz"],
)

load("@com_grail_bazel_toolchain//toolchain:rules.bzl", "llvm_toolchain")

llvm_toolchain(
    name = "llvm_toolchain",
    llvm_version = "7.0.0",
)
```

You can use the toolchain in your builds with
`--crosstool_top=@llvm_toolchain//:toolchain`

The toolchain can automatically detect your OS type, and use the right
pre-built binary distribution from llvm.org. The detection is currently
based on host OS and is not perfect, so some distributions, docker based
sandboxed builds, and remote execution builds will need toolchains configured
manually through the `distribution` attribute. We expect the detection logic to
grow through community contributions. We welcome PRs! :smile:

See in-code documentation in [rules.bzl](toolchain/rules.bzl) for available
attributes to `llvm_toolchain`.

For making changes to default settings for these toolchains, edit the
CROSSTOOL.tpl file. The file is in ASCII protobuf format.

https://github.com/bazelbuild/bazel/wiki/About-the-CROSSTOOL

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
  action). To overcome this, one can use
  `--experimental_sandbox_base=/dev/shm`.  However, not all environments might
  have enough shared memory available to load all the files in memory. That is
  why we have templated the paths to the toolchain as absolute paths. When
  running bazel actions, these paths will be available from inside the sandbox
  as part of the / read-only mount.

- The toolchain is known to also work with `rules_go`, both with absolute and
  relative paths.

Other examples of toolchain configuration:

https://github.com/bazelbuild/bazel/wiki/Building-with-a-custom-toolchain

https://github.com/vsco/bazel-toolchains
