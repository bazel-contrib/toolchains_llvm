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
)

load("@llvm_toolchain//:toolchains.bzl", "llvm_register_toolchains")

llvm_register_toolchains()

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
    name = "llvm_toolchain_with_sysroot",
    llvm_version = "12.0.0",
    sysroot = {
        "linux-x86_64": "@org_chromium_sysroot_linux_x64//:sysroot",
    },
    # We can share the downloaded LLVM distribution with the first configuration.
    toolchain_roots = {
        "": "@llvm_toolchain_llvm//",
    },
)

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
    sha256 = "59b862f50e710277f8ede96f083a5bb8d7c9595376146838b9580be90374ee1f",
    strip_prefix = "abseil-cpp-20210324.2",
    urls = ["https://github.com/abseil/abseil-cpp/archive/20210324.2.tar.gz"],
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
    sha256 = "8e968b5fcea1d2d64071872b12737bbb5514524ee5f0a4f54f5920266c261acb",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.28.0/rules_go-v0.28.0.zip",
        "https://github.com/bazelbuild/rules_go/releases/download/v0.28.0/rules_go-v0.28.0.zip",
    ],
)

load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies()

go_register_toolchains(version = "1.17")

# For testing rules_foreign_cc.
# See https://bazelbuild.github.io/rules_foreign_cc/0.6.0/cmake.html

http_archive(
    name = "rules_foreign_cc",
    sha256 = "69023642d5781c68911beda769f91fcbc8ca48711db935a75da7f6536b65047f",
    strip_prefix = "rules_foreign_cc-0.6.0",
    url = "https://github.com/bazelbuild/rules_foreign_cc/archive/0.6.0.tar.gz",
)

load("@rules_foreign_cc//foreign_cc:repositories.bzl", "rules_foreign_cc_dependencies")

rules_foreign_cc_dependencies()

_ALL_CONTENT = """\
filegroup(
    name = "all_srcs",
    srcs = glob(["**"]),
    visibility = ["//visibility:public"],
)
"""

http_archive(
    name = "pcre",
    build_file_content = _ALL_CONTENT,
    sha256 = "0b8e7465dc5e98c757cc3650a20a7843ee4c3edf50aaf60bb33fd879690d2c73",
    strip_prefix = "pcre-8.43",
    urls = [
        "https://mirror.bazel.build/ftp.pcre.org/pub/pcre/pcre-8.43.tar.gz",
        "https://ftp.pcre.org/pub/pcre/pcre-8.43.tar.gz",
    ],
)

http_archive(
    name = "rules_rust",
    sha256 = "531bdd470728b61ce41cf7604dc4f9a115983e455d46ac1d0c1632f613ab9fc3",
    strip_prefix = "rules_rust-d8238877c0e552639d3e057aadd6bfcf37592408",
    urls = [
        # `main` branch as of 2021-08-23
        "https://github.com/bazelbuild/rules_rust/archive/d8238877c0e552639d3e057aadd6bfcf37592408.tar.gz",
    ],
)

load("@rules_rust//rust:repositories.bzl", "rust_repositories")

rust_repositories(
    edition = "2018",
    version = "1.55.0",
)

# We're using `git2` as our Rust test because it links against C code
# (`libgit2-sys`) using `cc`, has tests, and is non-trivial but not _massive_.
#
# Ordinarily we'd just run the `rules_rust` tests but those break when run
# from another workspace (some of the skylib unittests expect paths within the
# main workspace and fail when paths like `external/rules_rust/...` are
# produced) and we want to test usage of the cc_toolchain via the `cc` crate
# anyways (as of this writing nothing in `@rules_rust//tests` seems to test
# this).
GIT2_RS_VER = "0.13.22"

GIT2_RS_SHA = "9c1cbbfc9a1996c6af82c2b4caf828d2c653af4fcdbb0e5674cc966eee5a4197"

http_archive(
    name = "git2",
    build_file_content = """
package(default_visibility = ["//visibility:public"])

load("@rules_rust//rust:defs.bzl", "rust_library", "rust_test")
load("@crates//:defs.bzl", "crates_from", "dev_crates_from", "crate")

DEV_CRATES = dev_crates_from("@git2//:Cargo.toml")
DEV_CRATES.remove(crate("paste")) # This is a proc_macro crate!

rust_library(
    name = "git2",
    srcs = glob(["src/**/*.rs"]),
    deps = crates_from("@git2//:Cargo.toml"),
)

rust_test(
    name = "git2-tests",
    crate = ":git2",
    deps = DEV_CRATES,
    proc_macro_deps = [crate("paste")],
)

[
    rust_test(
        name = t[len("tests/"):][:-len(".rs")],
        srcs = [t],
        deps = [":git2"] + DEV_CRATES,
        proc_macro_deps = [crate("paste")],
    )
    for t in glob(["tests/*.rs"])
]
""",
    canonical_id = GIT2_RS_VER,
    patch_args = ["-p1"],
    # We need to remove some `[target]` entries in `git2`'s `Cargo.toml` to
    # make `crate-universe` happy.
    #
    # See: https://github.com/bazelbuild/rules_rust/issues/783
    patches = ["//tests/rust:git2-rs-cargo-toml.patch"],
    sha256 = GIT2_RS_SHA,
    strip_prefix = "git2-{ver}".format(ver = GIT2_RS_VER),
    type = "tar.gz",
    url = "https://crates.io/api/v1/crates/git2/{ver}/download".format(ver = GIT2_RS_VER),
)

# Snippets for `crate_universe`:
RULES_RUST_CRATE_UNIVERSE_URL_TEMPLATE = "https://github.com/bazelbuild/rules_rust/releases/download/crate_universe-13/crate_universe_resolver-{host_triple}{extension}"

RULES_RUST_CRATE_UNIVERSE_SHA256_CHECKSUMS = {
    "aarch64-apple-darwin": "c6017cd8a4fee0f1796a8db184e9d64445dd340b7f48a65130d7ee61b97051b4",
    "aarch64-unknown-linux-gnu": "d0a310b03b8147e234e44f6a93e8478c260a7c330e5b35515336e7dd67150f35",
    "x86_64-apple-darwin": "762f1c77b3cf1de8e84d7471442af1314157efd90720c7e1f2fff68556830ee2",
    "x86_64-pc-windows-gnu": "c44bd97373d690587e74448b13267077d133f04e89bedfc9d521ae8ba55dddb9",
    "x86_64-unknown-linux-gnu": "aebf51af6a3dd33fdac463b35b0c3f4c47ab93e052099199673289e2025e5824",
}

load("@rules_rust//crate_universe:defs.bzl", "crate_universe")

crate_universe(
    name = "crates",
    cargo_toml_files = [
        "@git2//:Cargo.toml",
    ],
    resolver_download_url_template = RULES_RUST_CRATE_UNIVERSE_URL_TEMPLATE,
    resolver_sha256s = RULES_RUST_CRATE_UNIVERSE_SHA256_CHECKSUMS,
)

load("@crates//:defs.bzl", "pinned_rust_install")

pinned_rust_install()
