# Copyright 2018 The Bazel Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

workspace(
    name = "com_grail_bazel_toolchain",
)

load("@com_grail_bazel_toolchain//toolchain:deps.bzl", "bazel_toolchain_dependencies")

bazel_toolchain_dependencies()

load("@com_grail_bazel_toolchain//toolchain:rules.bzl", "llvm_toolchain")

llvm_toolchain(
    name = "llvm_toolchain",
    llvm_version = "12.0.0",
    extra_targets = [
        # NOTE: we do *not* use `wasm32-unknown-unknown` here; using `unknown`
        # makes the generated toolchain have no OS constraint which will result
        # in toolchain resolution matching the toolchain even for targets that
        # do have an OS.
        #
        # For example `wasm-unknown-unknown` which has no OS constraint will
        # match `wasm-unknown-wasi` which has an `os:wasi` constraint: even
        # though we'd _rather_ use `wasm32-unknown-wasi` when targeting
        # `wasm32-unknown-wasi`, it's not _wrong_ to use `wasm32-unknown-none`
        # since it *will* produce code that can run on `wasm32-unknown-wasi`
        # systems.
        #
        # In other words, the target platform has to satisfy the toolchain's
        # constraints, not the other way around.
        #
        # What we'd really like is for individual *targets* that require stdlib
        # and "platform" functionality to be able to say they need "os:wasi"
        # and thus need to be built with `wasm32-unknown-wasi` but this isn't
        # how toolchain resolution works; targets only filter the execution
        # platforms.
        #
        # The real solution is to actually specify an OS constraint even for
        # `unknown` target triple toolchains OR to always put `unknown` target
        # triple toolchains behind their OS-constraint-having peers in this
        # list so toolchain resolution will pick them as a _last_ resort.
        #
        # For now we don't map `unknown` to `os:none` in case there are
        # situations where this behavior is desirable (i.e. you want to fall
        # back to `thumbv7em-unknown-unknown` when you're asked to build for
        # a triple like `thumbv7em-unknown-netbsd`).
        #
        # Note that there is no default constraint for `//platforms/os`:
        # https://github.com/bazelbuild/platforms/blob/98939346da932eef0b54cf808622f5bb0928f00b/os/BUILD#L14
        "wasm32-unknown-none",
        "wasm32-unknown-wasi",
    ],
    # absolute_paths = True,
)

load("@llvm_toolchain//:toolchains.bzl", "llvm_register_toolchains", "register_toolchain")

llvm_register_toolchains()
register_toolchain("//tests:custom_toolchain_example")

## Toolchain example with a sysroot.
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# This sysroot is used by github.com/vsco/bazel-toolchains.
http_archive(
    name = "org_chromium_sysroot_linux_x64",
    build_file_content = """
filegroup(
  name = "sysroot",
  srcs = glob(["*/**"]),
  visibility = ["//visibility:public"],
)
""",
    sha256 = "84656a6df544ecef62169cfe3ab6e41bb4346a62d3ba2a045dc5a0a2ecea94a3",
    urls = ["https://commondatastorage.googleapis.com/chrome-linux-sysroot/toolchain/2202c161310ffde63729f29d27fe7bb24a0bc540/debian_stretch_amd64_sysroot.tar.xz"],
)

llvm_toolchain(
    name = "llvm_toolchain_linux_sysroot",
    llvm_version = "9.0.0",
    sysroot = {
        "linux": "@org_chromium_sysroot_linux_x64//:sysroot",
    },
)

# `bazel_skylib`; we're using its `build_test` test
http_archive(
    name = "bazel_skylib",
    urls = [
        "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
    ],
    sha256 = "1c531376ac7e5a180e0237938a2536de0c54d93f5c278634818e0efc952dd56c",
)

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")
bazel_skylib_workspace()

# Well known repos; present here only for testing.
http_archive(
    name = "com_google_googletest",
    sha256 = "9dc9157a9a1551ec7a7e43daea9a694a0bb5fb8bec81235d8a1e6ef64c716dcb",
    strip_prefix = "googletest-release-1.10.0",
    urls = ["https://github.com/google/googletest/archive/release-1.10.0.tar.gz"],
)

http_archive(
    name = "com_github_google_benchmark",
    sha256 = "3c6a165b6ecc948967a1ead710d4a181d7b0fbcaa183ef7ea84604994966221a",
    strip_prefix = "benchmark-1.5.0",
    urls = ["https://github.com/google/benchmark/archive/v1.5.0.tar.gz"],
)

http_archive(
    name = "com_google_absl",
    sha256 = "0db0d26f43ba6806a8a3338da3e646bb581f0ca5359b3a201d8fb8e4752fd5f8",
    strip_prefix = "abseil-cpp-20200225.1",
    urls = ["https://github.com/abseil/abseil-cpp/archive/20200225.1.tar.gz"],
)

http_archive(
    name = "openssl",
    build_file = "//tests/openssl:openssl.bazel",
    sha256 = "f6fb3079ad15076154eda9413fed42877d668e7069d9b87396d0804fdb3f4c90",
    strip_prefix = "openssl-1.1.1c",
    urls = ["https://www.openssl.org/source/openssl-1.1.1c.tar.gz"],
)

http_archive(
    name = "io_bazel_rules_go",
    sha256 = "7904dbecbaffd068651916dce77ff3437679f9d20e1a7956bff43826e7645fcc",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.25.1/rules_go-v0.25.1.tar.gz",
        "https://github.com/bazelbuild/rules_go/releases/download/v0.25.1/rules_go-v0.25.1.tar.gz",
    ],
)

load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies()

go_register_toolchains(version = "1.15.7")
