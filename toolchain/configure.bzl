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
# and send a PR on github. To compute the shasum block, you can use the script
# utils/llvm_checksums.sh
_sha256 = {
    # 6.0.0
    "clang+llvm-6.0.0-aarch64-linux-gnu.tar.xz": "69382758842f29e1f84a41208ae2fd0fae05b5eb7f5531cdab97f29dda3c2334",
    "clang+llvm-6.0.0-amd64-unknown-freebsd-10.tar.xz": "fee8352f5dee2e38fa2bb80ab0b5ef9efef578cbc6892e5c724a1187498119b7",
    "clang+llvm-6.0.0-armv7a-linux-gnueabihf.tar.xz": "4fda22e3d80994f343bfbdcae60f75e63ad44eb0998c59c559d706c11dd87b76",
    "clang+llvm-6.0.0-i386-unknown-freebsd-10.tar.xz": "13414a66b680760171e04f32071396eb6e5a179ff0b5a067d48c4b23744840f1",
    "clang+llvm-6.0.0-i686-linux-gnu-Fedora27.tar.xz": "2619e0a2542eec997daed3c7e597d99d5800cc3a07500b359429541a260d0207",
    "clang+llvm-6.0.0-mips-linux-gnu.tar.xz": "39820007ef6b2e3a4d05ec15feb477ce6e4e6e90180d00326e6ab9982ed8fe82",
    "clang+llvm-6.0.0-mipsel-linux-gnu.tar.xz": "5ff062f4838ac51a3500383faeb0731440f1c4473bf892258314a49cbaa66e61",
    "clang+llvm-6.0.0-x86_64-apple-darwin.tar.xz": "0ef8e99e9c9b262a53ab8f2821e2391d041615dd3f3ff36fdf5370916b0f4268",
    "clang+llvm-6.0.0-x86_64-linux-gnu-Fedora27.tar.xz": "2aada1f1a973d5d4d99a30700c4b81436dea1a2dcba8dd965acf3318d3ea29bb",
    "clang+llvm-6.0.0-x86_64-linux-gnu-debian8.tar.xz": "ff55cd0bdd0b67e22d1feee2e4c84dedc3bb053401330b64c7f6ac18e88a71f1",
    "clang+llvm-6.0.0-x86_64-linux-gnu-ubuntu-14.04.tar.xz": "114e78b2f6db61aaee314c572e07b0d635f653adc5d31bd1cd0bf31a3db4a6e5",
    "clang+llvm-6.0.0-x86_64-linux-gnu-ubuntu-16.04.tar.xz": "cc99fda45b4c740f35d0a367985a2bf55491065a501e2dd5d1ad3f97dcac89da",
    "clang+llvm-6.0.0-x86_64-linux-sles11.3.tar.xz": "1d4d30ebe4a7e5579644235b46513a1855d3ece865f7cc5ccd0ac5113c461ee7",
    "clang+llvm-6.0.0-x86_64-linux-sles12.2.tar.xz": "c144e17aab8dce8e8823a7a891067e27fd0686a49d8a3785cb64b0e51f08e2ee",

    # 6.0.1
    "clang+llvm-6.0.1-amd64-unknown-freebsd10.tar.xz": "6d1f67c9e7c3481106d5c9bfcb8a75e3876eb17a446a14c59c13cafd000c21d2",
    "clang+llvm-6.0.1-i386-unknown-freebsd10.tar.xz": "c6f65f2c42fa02e3b7e508664ded9b7a91ebafefae368dfa84b3d68811bcb924",
    "clang+llvm-6.0.1-x86_64-linux-gnu-ubuntu-14.04.tar.xz": "fa5416553ca94a8c071a27134c094a5fb736fe1bd0ecc5ef2d9bc02754e1bef0",
    "clang+llvm-6.0.1-x86_64-linux-gnu-ubuntu-16.04.tar.xz": "7ea204ecd78c39154d72dfc0d4a79f7cce1b2264da2551bb2eef10e266d54d91",
    "clang+llvm-6.0.1-x86_64-linux-sles11.3.tar.xz": "d128e2a7ea8b42418ec58a249e886ec2c736cbbbb08b9e11f64eb281b62bc574",
    "clang+llvm-6.0.1-x86_64-linux-sles12.3.tar.xz": "79c74f4764d13671285412d55da95df42b4b87064785cde3363f806dbb54232d",
}

def _download_llvm_preconfigured(rctx):
    llvm_version = rctx.attr.llvm_version

    url_base = []
    if rctx.attr.llvm_mirror:
        url_base += [rctx.attr.llvm_mirror]
    url_base += ["https://releases.llvm.org"]

    exec_result = rctx.execute([
        rctx.path(rctx.attr._llvm_release_name),
        llvm_version,
    ])
    if exec_result.return_code:
        fail("Failed to detect host OS version: \n%s\n%s" % (exec_result.stdout, exec_result.stderr))
    if exec_result.stderr:
        print(exec_result.stderr)
    basename = exec_result.stdout.strip()

    if basename not in _sha256:
        fail("Unknown LLVM release: %s\nPlease ensure file name is correct." % basename)

    urls = [
        (base + "/{0}/{1}".format(llvm_version, basename)).replace("+", "%2B")
        for base in url_base
    ]

    rctx.download_and_extract(
        urls,
        sha256 = _sha256[basename],
        stripPrefix = basename[:(len(basename) - len(".tar.xz"))],
    )

def _download_llvm(rctx):
    if rctx.os.name == "linux":
        urls = rctx.attr.urls["linux"]
        sha256 = rctx.attr.sha256["linux"]
        prefix = rctx.attr.strip_prefix["linux"]
    elif rctx.os.name == "mac os x":
        urls = rctx.attr.urls["darwin"]
        sha256 = rctx.attr.sha256["darwin"]
        prefix = rctx.attr.strip_prefix["darwin"]

    rctx.download_and_extract(urls, sha256 = sha256, stripPrefix = prefix)

def _llvm_toolchain_impl(rctx):
    repo_path = str(rctx.path(""))
    relative_path_prefix = "external/%s/" % rctx.name
    if rctx.attr.absolute_paths:
        toolchain_path_prefix = (repo_path + "/")
    else:
        toolchain_path_prefix = relative_path_prefix

    substitutions = {
        "%{llvm_version}": rctx.attr.llvm_version,
        "%{toolchain_path_prefix}": toolchain_path_prefix,
        "%{tools_path_prefix}": (repo_path + "/") if rctx.attr.absolute_paths else "",
        "%{debug_toolchain_path_prefix}": relative_path_prefix,
        "%{absolute_toolchain_path}": repo_path,
        "%{absolute_paths}": "True" if rctx.attr.absolute_paths else "False",
    }

    rctx.template(
        "CROSSTOOL",
        Label("@com_grail_bazel_toolchain//toolchain:CROSSTOOL.tpl"),
        substitutions,
    )
    rctx.template(
        "bin/cc_wrapper.sh",  # Co-located with the linker to help rules_go.
        Label("@com_grail_bazel_toolchain//toolchain:cc_wrapper.sh.tpl"),
        substitutions,
    )
    rctx.template(
        "Makevars",
        Label("@com_grail_bazel_toolchain//toolchain:Makevars.tpl"),
        substitutions,
    )
    rctx.template(
        "BUILD",
        Label("@com_grail_bazel_toolchain//toolchain:BUILD.tpl"),
        substitutions,
    )

    rctx.symlink("/usr/bin/ar", "bin/ar")  # For GoLink.

    # For GoCompile on macOS; compiler path is set from linker path.
    # It also helps clang driver sometimes for the linker to be colocated with the compiler.
    rctx.symlink("/usr/bin/ld", "bin/ld")
    if rctx.os.name == "linux":
        rctx.symlink("/usr/bin/ld.gold", "bin/ld.gold")
    else:
        # Add dummy file for non-linux so we don't have to put conditional logic in BUILD.
        rctx.file("bin/ld.gold")

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
        "_llvm_release_name": attr.label(
            default = "@com_grail_bazel_toolchain//toolchain:llvm_release_name.py",
            allow_single_file = True,
            doc = "Python module to output LLVM release name for the current OS.",
        ),
    },
    local = False,
    implementation = _llvm_toolchain_impl,
)

def conditional_cc_toolchain(name, cpu, darwin, absolute_paths = False):
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
