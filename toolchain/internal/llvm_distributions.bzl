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

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "read_netrc", "use_netrc")
load("//toolchain/internal:common.bzl", _arch = "arch", _attr_dict = "attr_dict", _exec_os_arch_dict_value = "exec_os_arch_dict_value", _os = "os")
load(
    "//toolchain/internal:llvm_distribution_info.bzl",
    _llvm_distributions = "LLVM_DISTRIBUTIONS",
    _llvm_distributions_base_url = "LLVM_DISTRIBUTIONS_BASE_URL",
)
load("//toolchain/internal:release_name.bzl", _llvm_release_name = "llvm_release_name")

def _get_auth(ctx, urls):
    """
    Given the list of URLs obtain the correct auth dict.

    Based on:
    https://github.com/bazelbuild/bazel/blob/793964e8e4268629d82fabbd08bf1a7718afa301/tools/build_defs/repo/http.bzl#L42
    """
    netrcpath = None
    if ctx.attr.netrc:
        netrcpath = ctx.attr.netrc
    elif not ctx.os.name.startswith("windows"):
        if "HOME" in ctx.os.environ:
            netrcpath = "%s/.netrc" % (ctx.os.environ["HOME"])
    elif "USERPROFILE" in ctx.os.environ:
        netrcpath = "%s/.netrc" % (ctx.os.environ["USERPROFILE"])

    if netrcpath and ctx.path(netrcpath).exists:
        netrc = read_netrc(ctx, netrcpath)
        return use_netrc(netrc, urls, ctx.attr.auth_patterns)

    return {}

def download_llvm(rctx):
    urls = []
    sha256 = None
    strip_prefix = None
    key = None
    update_sha256 = False
    if rctx.attr.urls:
        urls, sha256, strip_prefix, key = _urls(rctx)
        if not sha256:
            update_sha256 = True
    if not urls:
        urls, sha256, strip_prefix = _distribution_urls(rctx)

    res = rctx.download_and_extract(
        urls,
        sha256 = sha256,
        stripPrefix = strip_prefix,
        auth = _get_auth(rctx, urls),
    )

    updated_attrs = _attr_dict(rctx.attr)
    if update_sha256:
        updated_attrs["sha256"].update([(key, res.sha256)])
    return updated_attrs

def _urls(rctx):
    (key, urls) = _exec_os_arch_dict_value(rctx, "urls", debug = False)
    if not urls:
        print("LLVM archive URLs missing and no default fallback provided; will try 'distribution' attribute")  # buildifier: disable=print

    sha256 = rctx.attr.sha256.get(key, default = "")
    strip_prefix = rctx.attr.strip_prefix.get(key, default = "")

    return urls, sha256, strip_prefix, key

def _get_llvm_version(rctx):
    if rctx.attr.llvm_version:
        return rctx.attr.llvm_version
    if not rctx.attr.llvm_versions:
        fail("Neither 'llvm_version' nor 'llvm_versions' given.")
    (_, llvm_version) = _exec_os_arch_dict_value(rctx, "llvm_versions")
    if not llvm_version:
        fail("LLVM version string missing for ({os}, {arch})", os = _os(rctx), arch = _arch(rctx))
    return llvm_version

def _distribution_urls(rctx):
    llvm_version = _get_llvm_version(rctx)

    if rctx.attr.distribution == "auto":
        basename = _llvm_release_name(rctx, llvm_version)
    else:
        basename = rctx.attr.distribution

    if basename not in _llvm_distributions:
        fail("Unknown LLVM release: %s\nPlease ensure file name is correct." % basename)

    urls = []
    url_suffix = "{0}/{1}".format(llvm_version, basename).replace("+", "%2B")
    if rctx.attr.llvm_mirror:
        urls.append("{0}/{1}".format(rctx.attr.llvm_mirror, url_suffix))
    if rctx.attr.alternative_llvm_sources:
        for pattern in rctx.attr.alternative_llvm_sources:
            urls.append(pattern.format(llvm_version = llvm_version, basename = basename))
    urls.append("{0}{1}".format(_llvm_distributions_base_url[llvm_version], url_suffix))

    sha256 = _llvm_distributions[basename]

    strip_prefix = basename[:(len(basename) - len(".tar.xz"))]

    strip_prefix = strip_prefix.rstrip("-rhel86")

    return urls, sha256, strip_prefix
