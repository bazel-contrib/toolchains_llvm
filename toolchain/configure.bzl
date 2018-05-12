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

# If a new LLVM version is missing from this list, please add the shasum here
# and send a PR on github.
_llvm_sha256_linux = {
    "6.0.0": "cc99fda45b4c740f35d0a367985a2bf55491065a501e2dd5d1ad3f97dcac89da",
}

_llvm_sha256_darwin = {
    "6.0.0": "0ef8e99e9c9b262a53ab8f2821e2391d041615dd3f3ff36fdf5370916b0f4268",
}

def _download_llvm_preconfigured(rctx):
  llvm_version = rctx.attr.llvm_version

  url_base = []
  if rctx.attr.llvm_mirror:
    url_base += [rctx.attr.llvm_mirror]
  url_base += ["https://releases.llvm.org"]

  if rctx.os.name == "linux":
    prefix = "clang+llvm-{0}-x86_64-linux-gnu-ubuntu-16.04".format(llvm_version)
    sha256 = _llvm_sha256_linux[llvm_version]
  elif rctx.os.name == "mac os x":
    prefix = "clang+llvm-{0}-x86_64-apple-darwin".format(llvm_version)
    sha256 = _llvm_sha256_darwin[llvm_version]
  else:
    fail("Unsupported OS: " + rctx.os.name)

  urls = [(base + "/{0}/{1}.tar.xz".format(llvm_version, prefix)).replace("+", "%2B")
          for base in url_base]

  rctx.download_and_extract(urls, sha256=sha256, stripPrefix=prefix)

def _download_llvm(rctx):
  if rctx.os.name == "linux":
    urls = rctx.attr.urls["linux"]
    sha256 = rctx.attr.sha256["linux"]
    prefix = rctx.attr.strip_prefix["linux"]
  elif rctx.os.name == "mac os x":
    urls = rctx.attr.urls["darwin"]
    sha256 = rctx.attr.sha256["darwin"]
    prefix = rctx.attr.strip_prefix["darwin"]

  rctx.download_and_extract(urls, sha256=sha256, stripPrefix=prefix)

def _llvm_toolchain_impl(rctx):
  repo_path = str(rctx.path(""))
  if rctx.attr.absolute_paths:
    toolchain_path_prefix = (repo_path + "/")
  else:
    toolchain_path_prefix = "external/%s/" % rctx.name

  substitutions = {
      "%{llvm_version}": rctx.attr.llvm_version,
      "%{toolchain_path_prefix}": toolchain_path_prefix,
      "%{tools_path_prefix}": (repo_path + "/") if rctx.attr.absolute_paths else "",
      "%{absolute_paths}": "True" if rctx.attr.absolute_paths else "False",
  }

  rctx.template(
      "CROSSTOOL",
      Label("@com_grail_bazel_toolchain//toolchain:CROSSTOOL.tpl"),
      substitutions)
  rctx.template(
      "cc_wrapper.sh",
      Label("@com_grail_bazel_toolchain//toolchain:cc_wrapper.sh.tpl"),
      substitutions)
  rctx.template(
      "Makevars",
      Label("@com_grail_bazel_toolchain//toolchain:Makevars.tpl"),
      substitutions)
  rctx.template(
      "BUILD",
      Label("@com_grail_bazel_toolchain//toolchain:BUILD.tpl"),
      substitutions)

  # Repository implementation functions can be restarted, keep expensive ops at the end.
  if rctx.attr.urls:
    _download_llvm(rctx)
  else:
    _download_llvm_preconfigured(rctx)

llvm_toolchain = repository_rule(
    attrs = {
        "llvm_version": attr.string(
            default = "6.0.0",
            doc = "One of the supported versions of LLVM.",
        ),
        "llvm_mirror": attr.string(
            doc = "Mirror base for LLVM binaries if using the pre-configured URLs.",
        ),
        "urls": attr.string_list_dict(
            mandatory = False,
            doc = "URLs for each OS type (linux and darwin) if not using the pre-configured URLs.",
        ),
        "sha256": attr.string_dict(
            default = {
                "linux": "",
                "darwin": "",
            },
            doc = "sha256 of the archive for each OS type.",
        ),
        "strip_prefix": attr.string_dict(
            default = {
                "linux": "",
                "darwin": "",
            },
            doc = "Path prefix to strip from the extracted files.",
        ),
        "absolute_paths": attr.bool(
            default = False,
            doc = "Whether to use absolute paths in CROSSTOOL. Avoids sandbox overhead.",
        ),
    },
    local = False,
    implementation = _llvm_toolchain_impl,
)

def conditional_cc_toolchain(name, cpu, darwin, absolute_paths=False):
  # Toolchain macro for BUILD file to use conditional logic.

  if absolute_paths:
    native.cc_toolchain(
        name = name,
        all_files = ":empty",
        compiler_files = ":empty",
        cpu = "k8",
        dwp_files = ":empty",
        dynamic_runtime_libs = [":empty"],
        linker_files = ":empty",
        objcopy_files = ":empty",
        static_runtime_libs = [":empty"],
        strip_files = ":empty",
        supports_param_files = 0 if darwin else 1,
    )
  else:
    extra_files = [":cc_wrapper"] if darwin else []
    native.filegroup(name = name + "-all-files", srcs = [":all_components"] + extra_files)
    native.filegroup(name = name + "-compiler-files", srcs = [":compiler_components"] + extra_files)
    native.filegroup(name = name + "-linker-files", srcs = [":linker_components"] + extra_files)
    native.cc_toolchain(
        name = name,
        all_files = name + "-all-files",
        compiler_files = name + "-compiler-files",
        cpu = "k8",
        dwp_files = ":empty",
        dynamic_runtime_libs = [":empty"],
        linker_files = name + "-linker-files",
        objcopy_files = ":objcopy",
        static_runtime_libs = [":empty"],
        strip_files = ":empty",
        supports_param_files = 0 if darwin else 1,
    )
