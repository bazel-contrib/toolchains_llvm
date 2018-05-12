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

load("@com_grail_bazel_toolchain//toolchain:configure.bzl", "llvm_toolchain")

llvm_toolchain(
    name = "llvm_toolchain",
    llvm_version = "6.0.0",
    absolute_paths = True,
)
```

The in-built dictionary of URLs is good for Ubuntu 16.04 and macOS 10.13. For
other environments, provide your own sources through the `urls` attribute.

For making changes to default settings for these toolchains, edit the
CROSSTOOL.tpl file. The file is in ASCII protobuf format.

https://github.com/bazelbuild/bazel/wiki/About-the-CROSSTOOL

Notes:

- The LLVM toolchain archive is downloaded and extracted in the named
  repository.  People elsewhere have used wrapper scripts to avoid symlinking
and get better control of the environment in which the toolchain binaries are
run.

- Sandboxing the toolchain introduces a significant overhead (100ms per
  action). To overcome this, one can use `--experimental_sandbox_fs=/dev/shm`.
However, not all environments might have enough shared memory available to load
all the files in memory. In order to avoid sandboxing the toolchain entirely,
we can use absolute paths. When running bazel actions, these paths will be
available from inside the sandbox as part of the / read-only mount.

- While the C++ toolchain itself works well with relative paths (except the
  performance hit because of sandboxing), the go toolchain needs the linker and
the linked libraries as absolute. This is a limitation of the cpp configuration
fragment provided by skylark and used by the go toolchain.

- There is no R toolchain yet, so the Makevars file has been repurposed to
  provide the right configuration, but only when the configure script for
packages do not override the variables set in the Makevars.

- The toolchain is almost hermetic but borrows system headers and libraries
  from the user's system. If needed, one can package a sysroot for their build
environment and set `builtin_sysroot` in CROSSTOOL. If using relative paths, be
sure to add your sysroot files to the `all_files` attribute of the toolchain.

Other examples of toolchain configuration:

https://github.com/bazelbuild/bazel/wiki/Building-with-a-custom-toolchain

https://github.com/vsco/bazel-toolchains
