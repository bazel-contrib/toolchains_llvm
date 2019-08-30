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
_llvm_distributions = {
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

    # 7.0.0
    "clang+llvm-7.0.0-amd64-unknown-freebsd-10.tar.xz": "95ceb933ccf76e3ddaa536f41ab82c442bbac07cdea6f9fbf6e3b13cc1711255",
    "clang+llvm-7.0.0-i386-unknown-freebsd-10.tar.xz": "35460d34a8b3d856e0d7c0b2b20d31f0d1ec05908c830a81f586721e8f8fb04f",
    "clang+llvm-7.0.0-x86_64-apple-darwin.tar.xz": "b3ad93c3d69dfd528df9c5bb1a434367babb8f3baea47fbb99bf49f1b03c94ca",
    "clang+llvm-7.0.0-x86_64-linux-gnu-ubuntu-14.04.tar.xz": "5c90e61b06d37270bc26edb305d7e498e2c7be22d99e0afd9f2274ef5458575a",
    "clang+llvm-7.0.0-x86_64-linux-gnu-ubuntu-16.04.tar.xz": "69b85c833cd28ea04ce34002464f10a6ad9656dd2bba0f7133536a9927c660d2",
    "clang+llvm-7.0.0-x86_64-linux-sles11.3.tar.xz": "1a0a94a5cef357b885d02cf46b66109b6233f0af8f02be3da08e2daf646b5cf8",
    "clang+llvm-7.0.0-x86_64-linux-sles12.3.tar.xz": "1c303f1a7b90f0f1988387dfab16f1eadbe2b2152d86a323502068379941dd17",

    # 8.0.0
    "clang+llvm-8.0.0-aarch64-linux-gnu.tar.xz": "998e9ae6e89bd3f029ed031ad9355c8b43441302c0e17603cf1de8ee9939e5c9",
    "clang+llvm-8.0.0-amd64-unknown-freebsd11.tar.xz": "af15d14bd25e469e35ed7c43cb7e035bc1b2aa7b55d26ad597a43e72768750a8",
    "clang+llvm-8.0.0-armv7a-linux-gnueabihf.tar.xz": "ddcdc9df5c33b77740e4c27486905c44ecc3c4ec178094febeab60124deb0cc2",
    "clang+llvm-8.0.0-i386-unknown-freebsd11.tar.xz": "1ba88663ccda4e9fad93f8f35dde7ce04854abc0bcbb1d12a90cdc863e4a77b8",
    "clang+llvm-8.0.0-x86_64-apple-darwin.tar.xz": "94ebeb70f17b6384e052c47fef24a6d70d3d949ab27b6c83d4ab7b298278ad6f",
    "clang+llvm-8.0.0-x86_64-linux-gnu-ubuntu-16.04.tar.xz": "87b88d620284d1f0573923e6f7cc89edccf11d19ebaec1cfb83b4f09ac5db09c",
    "clang+llvm-8.0.0-x86_64-linux-gnu-ubuntu-18.04.tar.xz": "0f5c314f375ebd5c35b8c1d5e5b161d9efaeff0523bac287f8b4e5b751272f51",
    "clang+llvm-8.0.0-x86_64-linux-sles11.3.tar.xz": "7e2846ff60c181d1f27d97c23c25a2295f5730b6d88612ddd53b4cbb8177c4b9",

    # 8.0.1
    "clang+llvm-8.0.1-aarch64-linux-gnu.tar.xz": "3ca16b5f9e490d6c60712476c51db9d864e7d7f22904c91ad30ba8faee1ede64",
    "clang+llvm-8.0.1-amd64-unknown-freebsd11.tar.xz": "4ae625169fa0ae56cf534cddc6f8eda76123f89adac0de439d0e47885fccc813",
    "clang+llvm-8.0.1-armv7a-linux-gnueabihf.tar.xz": "c87b57496f8ec0f0fd74faa1c43b0ac12c156aae54d9be45169fd8f2b33b2181",
    "clang+llvm-8.0.1-i386-unknown-freebsd11.tar.xz": "f0ab06cce95f9339af3e27e728913414a7b775a5bdb6c90e2a4f67f8cf2a917e",
    "clang+llvm-8.0.1-powerpc64le-linux-rhel-7.4.tar.xz": "c26676326892119b015286efcd6f485b11c1055717454f6884c4ac5896ad5771",
    "clang+llvm-8.0.1-powerpc64le-linux-ubuntu-16.04.tar.xz": "7a8a422b360ad649f24e077eeee7098dd1496a82bee81792898f78ced2fe4a17",
    "clang+llvm-8.0.1-x86_64-linux-gnu-ubuntu-14.04.tar.xz": "0eb70c888c5a67f61e62ae502f4c935e3116e79e5cb3371a3be260f345fe1f16",
    "clang+llvm-8.0.1-x86_64-linux-sles11.3.tar.xz": "ec5d7fd082137ce5b72c7b4dde9a83c07a7e298773351ab6a0693a8200d0fa0c",
}

def _python(rctx):
    # Get path of the python interpreter.

    python3 = rctx.which("python3")
    python = rctx.which("python")
    python2 = rctx.which("python2")
    if python3:
        return python3
    elif python:
        return python
    elif python2:
        return python2
    else:
        fail("python not found")

def download_llvm_preconfigured(rctx):
    llvm_version = rctx.attr.llvm_version

    url_base = []
    if rctx.attr.llvm_mirror:
        url_base += [rctx.attr.llvm_mirror]
    url_base += ["https://releases.llvm.org"]

    if rctx.attr.distribution == "auto":
        exec_result = rctx.execute([
            _python(rctx),
            rctx.path(rctx.attr._llvm_release_name),
            llvm_version,
        ])
        if exec_result.return_code:
            fail("Failed to detect host OS version: \n%s\n%s" % (exec_result.stdout, exec_result.stderr))
        if exec_result.stderr:
            print(exec_result.stderr)
        basename = exec_result.stdout.strip()
    else:
        basename = rctx.attr.distribution

    if basename not in _llvm_distributions:
        fail("Unknown LLVM release: %s\nPlease ensure file name is correct." % basename)

    urls = [
        (base + "/{0}/{1}".format(llvm_version, basename)).replace("+", "%2B")
        for base in url_base
    ]

    rctx.download_and_extract(
        urls,
        sha256 = _llvm_distributions[basename],
        stripPrefix = basename[:(len(basename) - len(".tar.xz"))],
    )

# Download LLVM from the user-provided URLs and return True. If URLs were not provided, return
# False.
def download_llvm(rctx):
    if rctx.os.name == "linux":
        urls = rctx.attr.urls.get("linux", default = [])
        sha256 = rctx.attr.sha256.get("linux", default = "")
        prefix = rctx.attr.strip_prefix.get("linux", default = "")
    elif rctx.os.name == "mac os x":
        urls = rctx.attr.urls.get("darwin", default = [])
        sha256 = rctx.attr.sha256.get("darwin", default = "")
        prefix = rctx.attr.strip_prefix.get("darwin", default = "")
    else:
        fail("Unsupported OS: " + rctx.os.name)

    if not urls:
        return False

    rctx.download_and_extract(urls, sha256 = sha256, stripPrefix = prefix)
    return True
