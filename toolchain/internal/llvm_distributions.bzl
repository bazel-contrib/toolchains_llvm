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
load("//toolchain/internal:release_name.bzl", _llvm_release_name = "llvm_release_name")

# If a new LLVM version is missing from this list, please add the shasums here
# and send a PR on github. To compute the shasum block, you can run (for example):
#   utils/llvm_checksums.sh -g -v 15.0.6
#
# To find all available release versions, search for "tag_name" in
# https://api.github.com/repos/llvm/llvm-project/releases, or run (for example):
#   curl -s https://api.github.com/repos/llvm/llvm-project/releases | jq '.[].tag_name'
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
    "clang+llvm-8.0.0-x86_64-linux-gnu-ubuntu-14.04.tar.xz": "9ef854b71949f825362a119bf2597f744836cb571131ae6b721cd102ffea8cd0",
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

    # 9.0.0
    "clang+llvm-9.0.0-aarch64-linux-gnu.tar.xz": "f8f3e6bdd640079a140a7ada4eb6f5f05aeae125cf54b94d44f733b0e8691dc2",
    "clang+llvm-9.0.0-amd64-pc-solaris2.11.tar.xz": "86235763496b8174bca8fd1fcec2c99a3a29f8784814acef5c66634f86f81b16",
    "clang+llvm-9.0.0-amd64-unknown-freebsd11.tar.xz": "2a1f123a9d992c9719ef7677e127182ca707a5984a929f1c3f34fbb95ffbf6f3",
    "clang+llvm-9.0.0-armv7a-linux-gnueabihf.tar.xz": "ff6046bf98dbc85d7cb0c3c70456bc002b99a809bfc115657db2683ba61752ec",
    "clang+llvm-9.0.0-i386-unknown-freebsd11.tar.xz": "2d8d0b712946d6bc76317c4093ce77634ef6d502c343e1f3f6b841401db8fa56",
    "clang+llvm-9.0.0-powerpc64le-linux-rhel-7.4.tar.xz": "28052539e8e8ad204ee06910a143d992c67fef98662f83fa6f242f65ff29b386",
    "clang+llvm-9.0.0-powerpc64le-linux-ubuntu-16.04.tar.xz": "a8e7dc00e9eac47ea769eb1f5145e1e28f0610289f07f3275021f0556c169ddf",
    "clang+llvm-9.0.0-sparcv9-sun-solaris2.11.tar.xz": "7711e4cff908cad47ccab1d2e95bf3c8eb915585999c4e59bb42b10c3c502cfe",
    "clang+llvm-9.0.0-x86_64-darwin-apple.tar.xz": "b46e3fe3829d4eb30ad72993bf28c76b1e1f7e38509fbd44192a2ef7c0126fc7",
    "clang+llvm-9.0.0-x86_64-linux-gnu-ubuntu-14.04.tar.xz": "bea706c8f6992497d08488f44e77b8f0f87f5b275295b974aa8b194efba18cb8",
    "clang+llvm-9.0.0-x86_64-linux-gnu-ubuntu-16.04.tar.xz": "5c1473c2611e1eac4ed1aeea5544eac5e9d266f40c5623bbaeb1c6555815a27d",
    "clang+llvm-9.0.0-x86_64-linux-gnu-ubuntu-18.04.tar.xz": "a23b082b30c128c9831dbdd96edad26b43f56624d0ad0ea9edec506f5385038d",
    "clang+llvm-9.0.0-x86_64-linux-sles11.3.tar.xz": "c80b5b10df191465df8cee8c273d9c46715e6f27f80fef118ad4ebb7d9f3a7d3",
    "clang+llvm-9.0.0-x86_64-pc-linux-gnu.tar.xz": "616c5f75418c88a72613b6d0a93178028f81357777226869ea6b34c23d08a12d",

    # 10.0.0
    "clang+llvm-10.0.0-aarch64-linux-gnu.tar.xz": "c2072390dc6c8b4cc67737f487ef384148253a6a97b38030e012c4d7214b7295",
    "clang+llvm-10.0.0-amd64-pc-solaris2.11.tar.xz": "aaf6865542bd772e30be3abf620340a050ed5e4297f8be347e959e5483d9f159",
    "clang+llvm-10.0.0-amd64-unknown-freebsd11.tar.xz": "56d58da545743d5f2947234d413632fd2b840e38f2bed7369f6e65531af36a52",
    "clang+llvm-10.0.0-armv7a-linux-gnueabihf.tar.xz": "ad136e0d8ce9ac1a341a54513dfd313a7a64c49afa7a69d51cdc2118f7fdc350",
    "clang+llvm-10.0.0-i386-unknown-freebsd11.tar.xz": "310ed47e957c226b0de17130711505366c225edbed65299ac2c3d59f9a59a41a",
    "clang+llvm-10.0.0-powerpc64le-linux-rhel-7.4.tar.xz": "958b8a774eae0bb25515d7fb2f13f5ead1450f768ffdcff18b29739613b3c457",
    "clang+llvm-10.0.0-powerpc64le-linux-ubuntu-16.04.tar.xz": "2d6298720d6aae7fcada4e909f0949d63e94fd0370d20b8882cdd91ceae7511c",
    "clang+llvm-10.0.0-sparcv9-sun-solaris2.11.tar.xz": "725c9205550cabb6d8e0d8b1029176113615809dcc880b347c1577aecdf2af4c",
    "clang+llvm-10.0.0-x86_64-apple-darwin.tar.xz": "633a833396bf2276094c126b072d52b59aca6249e7ce8eae14c728016edb5e61",
    "clang+llvm-10.0.0-x86_64-linux-gnu-ubuntu-18.04.tar.xz": "b25f592a0c00686f03e3b7db68ca6dc87418f681f4ead4df4745a01d9be63843",
    "clang+llvm-10.0.0-x86_64-linux-sles11.3.tar.xz": "a7a3c2a7aff813bb10932636a6f1612e308256a5e6b5a5655068d5c5b7f80e86",

    # 10.0.1
    "clang+llvm-10.0.1-aarch64-linux-gnu.tar.xz": "90dc69a4758ca15cd0ffa45d07fbf5bf4309d47d2c7745a9f0735ecffde9c31f",
    "clang+llvm-10.0.1-amd64-unknown-freebsd11.tar.xz": "290897c328f75df041d1abda6e25a50c2e6a0a3d939b5069661bb966bf7ac843",
    "clang+llvm-10.0.1-armv7a-linux-gnueabihf.tar.xz": "adf90157520cd5e0931b9f186bed0f0463feda56370de4eba51766946f57b02b",
    "clang+llvm-10.0.1-i386-unknown-freebsd11.tar.xz": "f404976ad92cf846b7915cd43cd251e090a5e7524809ab96f5a65216988b2b26",
    "clang+llvm-10.0.1-powerpc64le-linux-rhel-7.4.tar.xz": "27359cae558905bf190834db11bbeaea433777a360744e9f79bfe69226a19117",
    "clang+llvm-10.0.1-powerpc64le-linux-ubuntu-16.04.tar.xz": "c19edf5c1f5270ae9124a3873e689a3309a9ad075373a75c0791abf4bf72602e",
    "clang+llvm-10.0.1-x86_64-apple-darwin.tar.xz": "1154a24597ab77801980dfd5ae4a13c117d6b482bab015baa410aeba443ffd92",
    "clang+llvm-10.0.1-x86_64-linux-gnu-ubuntu-16.04.tar.xz": "48b83ef827ac2c213d5b64f5ad7ed082c8bcb712b46644e0dc5045c6f462c231",
    "clang+llvm-10.0.1-x86_64-linux-sles12.4.tar.xz": "59f35fc7967b740315edf31a54b228ae5da8a54f499e37d424d67b7107217ae4",

    # 11.0.0
    "clang+llvm-11.0.0-amd64-pc-solaris2.11.tar.xz": "031699337d703fe42843a8326f94079fd67e46b60f25be5bdf47664e158e0b43",
    "clang+llvm-11.0.0-sparcv9-sun-solaris2.11.tar.xz": "3f2bbbbd9aac9809bcc561d73b0db39ecd64fa099fac601f929da5e95a63bdc5",
    "clang+llvm-11.0.0-x86_64-apple-darwin.tar.xz": "b93886ab0025cbbdbb08b46e5e403a462b0ce034811c929e96ed66c2b07fe63a",
    "clang+llvm-11.0.0-x86_64-linux-gnu-ubuntu-16.04.tar.xz": "abfe77fa4c2ceda16455fac9dba58962af9173c5aa85d5bb8ca4f5165ef87a19",
    "clang+llvm-11.0.0-x86_64-linux-gnu-ubuntu-20.04.tar.xz": "829f5fb0ebda1d8716464394f97d5475d465ddc7bea2879c0601316b611ff6db",
    "clang+llvm-11.0.0-x86_64-linux-sles12.4.tar.xz": "ce3e2e9788e0136f3082eb3199c6e2dd171f4e7c98310f83fc284c5ba734d27a",

    # 11.0.1
    "clang+llvm-11.0.1-aarch64-linux-gnu.tar.xz": "39b3d3e3b534e327d90c77045058e5fc924b1a81d349eac2be6fb80f4a0e40d4",
    "clang+llvm-11.0.1-amd64-unknown-freebsd11.tar.xz": "cd0a6da1825bc7440c5a8dfa22add4ee91953c45aa0e5597ba1a5caf347f807d",
    "clang+llvm-11.0.1-amd64-unknown-freebsd12.tar.xz": "2daa205f87d2b81a281f3883c2102cd69ac017193b19ea30f914b57f904c7c4b",
    "clang+llvm-11.0.1-armv7a-linux-gnueabihf.tar.xz": "5c6b3a1104ac3999c11e18b42c7feca47e0bb894d55b938aba32b1c362402a52",
    "clang+llvm-11.0.1-i386-unknown-freebsd11.tar.xz": "e32ad587e800145a7868449b1416e25d05a6ca08c071ecc8173cf9e1b0b7dcdd",
    "clang+llvm-11.0.1-i386-unknown-freebsd12.tar.xz": "46e88ce3a5efef198cade0cf29ee152f3361ca4488fd7701cc79485c06aa93b8",
    "clang+llvm-11.0.1-powerpc64le-linux-rhel-7.4.tar.xz": "d270ded2cbcb76588bbf71dad2e3657961896bfadf7ff4da57d07870da537873",
    "clang+llvm-11.0.1-powerpc64le-linux-ubuntu-18.04.tar.xz": "a60a35f6c9f280268df8afe76f4a5349426f8b8eefd40eb885eae80b6e3647d0",
    "clang+llvm-11.0.1-x86_64-linux-gnu-ubuntu-16.04.tar.xz": "67f18660231d7dd09dc93502f712613247b7b4395e6f48c11226629b250b53c5",
    "clang+llvm-11.0.1-x86_64-linux-gnu-ubuntu-20.10.tar.xz": "b60f68581182ace5f7d4a72e5cce61c01adc88050acb72b2070ad298c25071bc",
    "clang+llvm-11.0.1-x86_64-linux-sles12.4.tar.xz": "77cd59cf6f932cf2b3c9a68789d1bd3f7ba9f471a28f6ba25e25deb1a0806e0d",

    # 11.1.0
    "clang+llvm-11.1.0-aarch64-linux-gnu.tar.xz": "18df38247af3fba0e0e2991fb00d7e3cf3560b4d3509233a14af699ef0039e1c",
    "clang+llvm-11.1.0-amd64-unknown-freebsd11.tar.xz": "645e24018aa2694d8ccb44139f44a0d3af97fa8eab785faecb7a228ebe76ac7e",
    "clang+llvm-11.1.0-amd64-unknown-freebsd12.tar.xz": "430284b75248ab2dd3ebb8718d8bbb19cc8b9b62f4707ae47a61827b3ba59836",
    "clang+llvm-11.1.0-armv7a-linux-gnueabihf.tar.xz": "18a3c3aedf1181aa18da3f5d0a2c67366c6d5fb398ac00e461298d9584be5c68",
    "clang+llvm-11.1.0-i386-unknown-freebsd11.tar.xz": "ddc451c1094d0c8912160912d7c20d28087782758e0a8d145f301a18ddcea558",
    "clang+llvm-11.1.0-i386-unknown-freebsd12.tar.xz": "3c23d3b97f869382b33878d8a5210056c60d5e749acfeea0354682bb013f5a20",
    "clang+llvm-11.1.0-powerpc64le-linux-rhel-7.4.tar.xz": "8ff13bb70f1eb8efe61b1899e4d05d6f15c18a14a9ffa883f54f243b060fa778",
    "clang+llvm-11.1.0-powerpc64le-linux-ubuntu-18.04.tar.xz": "2741183e4ea5fccc86ec2d9ce226edcf00da90b07731b04540edb5025cc695c1",
    "clang+llvm-11.1.0-x86_64-linux-gnu-ubuntu-16.04.tar.xz": "c691a558967fb7709fb81e0ed80d1f775f4502810236aa968b4406526b43bee1",
    "clang+llvm-11.1.0-x86_64-linux-gnu-ubuntu-20.10.tar.xz": "29b07422da4bcea271a88f302e5f84bd34380af137df18e33251b42dd20c26d7",

    # 12.0.0
    "clang+llvm-12.0.0-aarch64-linux-gnu.tar.xz": "d05f0b04fb248ce1e7a61fcd2087e6be8bc4b06b2cc348792f383abf414dec48",
    "clang+llvm-12.0.0-amd64-unknown-freebsd11.tar.xz": "8ff2ae0863d4cbe88ace6cbcce64a1a6c9a8f1237f635125a5d580b2639bba61",
    "clang+llvm-12.0.0-amd64-unknown-freebsd12.tar.xz": "0a90d2cf8a3d71d7d4a6bee3e085405ebc37a854311bce82d6845d93b19fcc87",
    "clang+llvm-12.0.0-armv7a-linux-gnueabihf.tar.xz": "697d432c2572e48fc04118fc7cec63c9477ef2e8a7cca2c0b32e52f9705ab1cc",
    "clang+llvm-12.0.0-i386-unknown-freebsd11.tar.xz": "8298a026f74165bf6088c1c942c22bd7532b12cd2b916f7673bdaf522abe41b0",
    "clang+llvm-12.0.0-i386-unknown-freebsd12.tar.xz": "1e61921735fd11754df193826306f0352c99ca6013e22f40a7fc77f0b20162be",
    "clang+llvm-12.0.0-x86_64-apple-darwin.tar.xz": "7bc2259bf75c003f644882460fc8e844ddb23b27236fe43a2787870a4cd8ab50",
    "clang+llvm-12.0.0-x86_64-linux-gnu-ubuntu-16.04.tar.xz": "9694f4df031c614dbe59b8431f94c68631971ad44173eecc1ea1a9e8ee27b2a3",
    "clang+llvm-12.0.0-x86_64-linux-gnu-ubuntu-20.04.tar.xz": "a9ff205eb0b73ca7c86afc6432eed1c2d49133bd0d49e47b15be59bbf0dd292e",
    "clang+llvm-12.0.0-x86_64-linux-sles12.4.tar.xz": "00c25261e303080c2e8d55413a73c60913cdb39cfd47587d6817a86fe52565e9",

    # 12.0.1
    "clang+llvm-12.0.1-amd64-unknown-freebsd11.tar.xz": "94dfe48d9e483283edbee968056d487a850b30de25258fa48f049cca3ede5db4",
    "clang+llvm-12.0.1-amd64-unknown-freebsd12.tar.xz": "38857da36489880b0504ae7142b74abe41cf18711a6bb25ca96792d8190e8b0e",
    "clang+llvm-12.0.1-i386-unknown-freebsd11.tar.xz": "346e14e5a9189838704f096e65579c8e1915f95dcc291aa7f20626ccf9767e04",
    "clang+llvm-12.0.1-i386-unknown-freebsd12.tar.xz": "1f3b5e99e82165bf3442120ee3cb2c95ca96129cf45c85a52ec8973f8904529d",
    "clang+llvm-12.0.1-armv7a-linux-gnueabihf.tar.xz": "1ec685b5026f9cc5e7316a5ff2dffd8ff54ad9941e642df19062cc1359842c86",
    "clang+llvm-12.0.1-aarch64-linux-gnu.tar.xz": "3d4ad804b7c85007686548cbc917ab067bf17eaedeab43d9eb83d3a683d8e9d4",
    "clang+llvm-12.0.1-powerpc64le-linux-rhel-7.9.tar.xz": "9849fa17fb7eb666744f1e2ce8dcb5d28753c4c482cc6f5e3d2b5ad2108dc2de",
    "clang+llvm-12.0.1-powerpc64le-linux-ubuntu-18.04.tar.xz": "271b9605b74d904d3cc05dd6a61e927fd5a46d5f6b7541cdc67186eb02b22e4c",
    "clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-16.04.tar.xz": "6b3cc55d3ef413be79785c4dc02828ab3bd6b887872b143e3091692fc6acefe7",

    # 13.0.0
    "clang+llvm-13.0.0-amd64-unknown-freebsd12.tar.xz": "e579747a36ff78aa0a5533fe43bc1ed1f8ed449c9bfec43c358d953ffbbdcf76",
    "clang+llvm-13.0.0-amd64-unknown-freebsd13.tar.xz": "c4f15e156afaa530eb47ba13c46800275102af535ed48e395aed4c1decc1eaa1",
    "clang+llvm-13.0.0-i386-unknown-freebsd12.tar.xz": "4d14b19c082438a5ceed61e538e5a0298018b1773e8ba2e990f3fbe33492f48f",
    "clang+llvm-13.0.0-i386-unknown-freebsd13.tar.xz": "f8e105c6ac2fd517ae5ed8ef9b9bab4b015fe89a06c90c3dd5d5c7933dca2276",
    "clang+llvm-13.0.0-powerpc64le-linux-rhel-7.9.tar.xz": "cfade83f6da572a8ab0e4796d1f657967b342e98202c26e76c857879fb2fa2d2",
    "clang+llvm-13.0.0-powerpc64le-linux-ubuntu-18.04.tar.xz": "5d79e9e2919866a91431589355f6d07f35d439458ff12cb8f36093fb314a7028",
    "clang+llvm-13.0.0-x86_64-apple-darwin.tar.xz": "d051234eca1db1f5e4bc08c64937c879c7098900f7a0370f3ceb7544816a8b09",
    "clang+llvm-13.0.0-x86_64-linux-gnu-ubuntu-16.04.tar.xz": "76d0bf002ede7a893f69d9ad2c4e101d15a8f4186fbfe24e74856c8449acd7c1",
    "clang+llvm-13.0.0-x86_64-linux-gnu-ubuntu-20.04.tar.xz": "2c2fb857af97f41a5032e9ecadf7f78d3eff389a5cd3c9ec620d24f134ceb3c8",

    # 13.0.1
    "clang+llvm-13.0.1-aarch64-linux-gnu.tar.xz": "15ff2db12683e69e552b6668f7ca49edaa01ce32cb1cbc8f8ed2e887ab291069",
    "clang+llvm-13.0.1-amd64-unknown-freebsd12.tar.xz": "8101c8d3a920bf930b33987ada5373f43537c5de8c194be0ea10530fd0ad5617",
    "clang+llvm-13.0.1-amd64-unknown-freebsd13.tar.xz": "f1ba8ec77b5e82399af738ad9897a8aafc11c5692ceb331c8373eae77018d428",
    "clang+llvm-13.0.1-armv7a-linux-gnueabihf.tar.xz": "1215720114538f57acbe2f3b0614c23f4fc551ba2976afa3779a3c01aaaf1221",
    "clang+llvm-13.0.1-i386-unknown-freebsd12.tar.xz": "e3c921e0f130afa6a6ebac23c31b66b32563a5ec53a2f4ed4676f31a81379f70",
    "clang+llvm-13.0.1-i386-unknown-freebsd13.tar.xz": "e85c46bd64a0217f3df1f42421a502648d6741ef29fd5d44674b87af119ce25d",
    "clang+llvm-13.0.1-powerpc64le-linux-rhel-7.9.tar.xz": "ab659c290536182a99c064d4537d2fb1273bb2b1bf8c6a43866f033bf1ece4a8",
    "clang+llvm-13.0.1-powerpc64le-linux-ubuntu-18.04.5.tar.xz": "7a4be2508aa0b4ee3f72c312af4b62ea14581a5db61aa703ea0822f46e5598cb",
    "clang+llvm-13.0.1-x86_64-apple-darwin.tar.xz": "dec02d17698514d0fc7ace8869c38937851c542b02adf102c4e898f027145a4d",
    "clang+llvm-13.0.1-x86_64-linux-gnu-ubuntu-18.04.tar.xz": "84a54c69781ad90615d1b0276a83ff87daaeded99fbc64457c350679df7b4ff0",

    # 14.0.0
    "clang+llvm-14.0.0-aarch64-linux-gnu.tar.xz": "1792badcd44066c79148ffeb1746058422cc9d838462be07e3cb19a4b724a1ee",
    "clang+llvm-14.0.0-amd64-pc-solaris2.11.tar.xz": "a708470fdbaadf530d6cfd56f92fde1328cb47ef8439ecf1a2126523e7c94a50",
    "clang+llvm-14.0.0-amd64-unknown-freebsd12.tar.xz": "7eaff7ee2a32babd795599f41f4a5ffe7f161721ebf5630f48418e626650105e",
    "clang+llvm-14.0.0-amd64-unknown-freebsd13.tar.xz": "b68d73fd57be385e7f06046a87381f7520c8861f492c294e6301d2843d9a1f57",
    "clang+llvm-14.0.0-armv7a-linux-gnueabihf.tar.xz": "17d5f60c3d5f9494be7f67b2dc9e6017cd5e8457e53465968a54ec7069923bfe",
    "clang+llvm-14.0.0-i386-unknown-freebsd12.tar.xz": "5ed9d93a8425132e8117d7061d09c2989ce6b2326f25c46633e2b2dee955bb00",
    "clang+llvm-14.0.0-i386-unknown-freebsd13.tar.xz": "81f49eb466ce9149335ac8918a5f02fa724d562a94464ed13745db0165b4a220",
    "clang+llvm-14.0.0-powerpc64-ibm-aix-7.2.tar.xz": "4ad5866de6c69d989cbbc989201b46dfdcd7d2b23a712fcad7baa09c204f10de",
    "clang+llvm-14.0.0-powerpc64le-linux-rhel-7.9.tar.xz": "7a31de37959fdf3be897b01f284a91c28cd38a2e2fa038ff58121d1b6f6eb087",
    "clang+llvm-14.0.0-powerpc64le-linux-ubuntu-18.04.tar.xz": "2d504c4920885c86b306358846178bc2232dfac83b47c3b1d05861a8162980e6",
    "clang+llvm-14.0.0-sparcv9-sun-solaris2.11.tar.xz": "b342cdaaea3b44de5b0f45052e2df49bcdf69dcc8ad0c23ec5afc04668929681",
    "clang+llvm-14.0.0-x86_64-apple-darwin.tar.xz": "cf5af0f32d78dcf4413ef6966abbfd5b1445fe80bba57f2ff8a08f77e672b9b3",
    "clang+llvm-14.0.0-x86_64-linux-gnu-ubuntu-18.04.tar.xz": "61582215dafafb7b576ea30cc136be92c877ba1f1c31ddbbd372d6d65622fef5",
    "clang+llvm-14.0.0-x86_64-linux-sles12.4.tar.xz": "78f70cc94c3b6f562455b15cebb63e75571d50c3d488d53d9aa4cd9dded30627",

    # 14.0.1
    "clang+llvm-14.0.1-aarch64-linux-gnu.tar.xz": "0f1fe0c927ebc2fc9e7d55188b80cd4982e49ae2a667bff1199435fb21159f52",
    "clang+llvm-14.0.1-amd64-pc-solaris2.11.tar.xz": "220c3f690a6e7ca2fb180594071d39556a4ea0951672397c9f5946656f088956",
    "clang+llvm-14.0.1-amd64-unknown-freebsd12.tar.xz": "755023705bb7caa9db3f06c02908f840612a1497da4da617d1022522a978f4de",
    "clang+llvm-14.0.1-amd64-unknown-freebsd13.tar.xz": "657497b3525b9ae115a019bb5ea401f198e087761f17155f4335a5df1f6994df",
    "clang+llvm-14.0.1-armv7a-linux-gnueabihf.tar.xz": "be17b515b4a7938959ada101ca72fd9f59faf605e5838211e8915a36bf68f0d5",
    "clang+llvm-14.0.1-powerpc64-ibm-aix-7.2.tar.xz": "0426b0b87c6275436f8285f4998f5588139405d61a3d5edc64c88119b57f4ebf",
    "clang+llvm-14.0.1-powerpc64le-linux-rhel-8.4.tar.xz": "222238faa88a46b65a0610923bb27ab357e7eb1ac3f894c89c0b474b516da4bf",
    "clang+llvm-14.0.1-powerpc64le-linux-ubuntu-18.04.tar.xz": "761e8a3ce4efa6ee4e98f777b34a5fd7db64a1e0baf8c6eab51c078d646e567f",
    "clang+llvm-14.0.1-sparcv9-sun-solaris2.11.tar.xz": "ba2e06fda8e0c5eb7daec3159b43ac1b41a9ef6a576cab772b0bc5bfc3ba5851",
    "clang+llvm-14.0.1-x86_64-apple-darwin.tar.xz": "43149390e95b1cdbf1d4ef2e9d214bbb6d35858ceb2df27245868e06bc4fc44c",

    # 14.0.2
    "clang+llvm-14.0.2-aarch64-linux-gnu.tar.xz": "ad6d065a2cf1c67698cc7f368722b1adc3fa2d7c9401446f0046612b6c90edc4",
    "clang+llvm-14.0.2-amd64-unknown-freebsd12.tar.xz": "1df946b25963e941253e2aad31c92979630af9b12fc8be2538e191013a151bb1",
    "clang+llvm-14.0.2-amd64-unknown-freebsd13.tar.xz": "0acab62c60dfb7449cd635000300feeff19717a14056d33a90c0b33fd0ffcb01",
    "clang+llvm-14.0.2-powerpc64-ibm-aix-7.2.tar.xz": "837482b5ca8f144365bd1810910cbce39d0d3c4c97a8aa4ac8612d0ffb248407",
    "clang+llvm-14.0.2-x86_64-apple-darwin.tar.xz": "7037efca192eb04a569a7422bd5d974a0af315b979252b6d956d2657ac33d672",

    # 14.0.3
    "clang+llvm-14.0.3-aarch64-linux-gnu.tar.xz": "36958cf3f1be9e91f33b0ce86afe049c2cf89c320996f963ee232c2405a811ec",
    "clang+llvm-14.0.3-amd64-unknown-freebsd12.tar.xz": "62737fb1da58af725c0c93015c5d8250a723d976e8d7ef26b6445f8cb23c4f91",
    "clang+llvm-14.0.3-amd64-unknown-freebsd13.tar.xz": "2c8d9537af54626395a3dbd0aa7ccd2c76aab567507a8293ab75967ab784162d",
    "clang+llvm-14.0.3-armv7a-linux-gnueabihf.tar.xz": "2279cd46a7b619a0cb66d54012917c889e37c56f718ab92813dc13131f2fd805",
    "clang+llvm-14.0.3-powerpc64-ibm-aix-7.2.tar.xz": "2afa547a182248a36815f31a427faced639286881bc975804563994e6c962552",
    "clang+llvm-14.0.3-powerpc64le-linux-rhel-8.4.tar.xz": "6c2d79cebec1a0ba96c13bca613b01b7ebf194fcbd0ecf4d3432d4a7804e71ff",
    "clang+llvm-14.0.3-powerpc64le-linux-ubuntu-18.04.tar.xz": "5ae686c74ab0b9b2930861c0d2875fcd4db22a9c6bdd9c9507120a0f808c17c8",
    "clang+llvm-14.0.3-x86_64-apple-darwin.tar.xz": "90e07966dbaf87de0cbb206ab763023f9c559612c91d43a1711af7dc026cfb81",

    # 14.0.4
    "clang+llvm-14.0.4-aarch64-linux-gnu.tar.xz": "0c960d50c83360d81e698120f131cf004676cbe5ac6db6fbe67a0950f3cde2d1",
    "clang+llvm-14.0.4-amd64-unknown-freebsd12.tar.xz": "80814b7a7a56151b204aa8cb621df22c645f41c834920c3818d6b6eadb175a79",
    "clang+llvm-14.0.4-amd64-unknown-freebsd13.tar.xz": "282696627bb3f2d07dd38d7c67ecff97877f2b984d712dbcb506e3f0a63ad1f8",
    "clang+llvm-14.0.4-armv7a-linux-gnueabihf.tar.xz": "09bb79557235aee16badc4e3db86a121b0b3c7af226e093c908a1c66c5a0c4c4",
    "clang+llvm-14.0.4-powerpc64-ibm-aix-7.2.tar.xz": "2af35c3e1b60f68551cd92a31b66c6ad9b2986e9cb3f2aa924e225ae254d1a46",
    "clang+llvm-14.0.4-powerpc64le-linux-rhel-8.4.tar.xz": "0c35b2ebd22c081d19679889e4afedf2060f1649d1060d45e0fa00f61dfba542",
    "clang+llvm-14.0.4-powerpc64le-linux-ubuntu-18.04.5.tar.xz": "5736642965dca707282e22d084e3ec621f0fc8db8779e82f8d667942112bdac6",
    "clang+llvm-14.0.4-x86_64-apple-darwin.tar.xz": "f6d9801b0bd78479229d21e2d5650c5a61f9ab1b6f80bad0dccf4b7a7eb30abf",

    # 14.0.5
    "clang+llvm-14.0.5-aarch64-linux-gnu.tar.xz": "e8138f24d716ef9714e259ab276e6ef74c8adcf9af0270464a8a01c24a583ea8",
    "clang+llvm-14.0.5-amd64-unknown-freebsd12.tar.xz": "1edee096aa23e2c0b75352953c4f04a105fd9521de6742d4652b44ab9009636c",
    "clang+llvm-14.0.5-amd64-unknown-freebsd13.tar.xz": "52c62e29f2cd8d72d592cded337e47bb8cb0998f7ee5f3c1b168790bdce154e7",
    "clang+llvm-14.0.5-armv7a-linux-gnueabihf.tar.xz": "f80dbd2684f8fe13ce675236e5ef0235fdf5239d442c21f066245d7fb98ba11c",
    "clang+llvm-14.0.5-powerpc64-ibm-aix-7.2.tar.xz": "8b2dd8fb508d295cf72be84a592a3592824fd4d881a9fcd6c2a64ba4954fe944",
    "clang+llvm-14.0.5-powerpc64le-linux-rhel-8.4.tar.xz": "003314da4c23996f4fb40590e152ec2f42cd2c9ad71d70be68fcc76a746cb093",
    "clang+llvm-14.0.5-powerpc64le-linux-ubuntu-18.04.5.tar.xz": "8d4bfe5cd53515adde095f07395356d71287a6ff27fa3e2219850b865f19d113",
    "clang+llvm-14.0.5-x86_64-apple-darwin.tar.xz": "66cf1b8e00289a567b2f5f740f068b7682e27ccf048647b836d3624376a64705",

    # 14.0.6
    "clang+llvm-14.0.6-aarch64-linux-gnu.tar.xz": "1a81fda984f5e607584916fdf69cf41e5385b219b983544d2c1a14950d5a65cf",
    "clang+llvm-14.0.6-amd64-unknown-freebsd12.tar.xz": "b0a7b86dacb12afb8dd2ca99ea1b894d9cce84aab7711cb1964b3005dfb09af3",
    "clang+llvm-14.0.6-amd64-unknown-freebsd13.tar.xz": "503e806ae67323c4f790ea2b1fe21e52809814d6a51263e2618f0c22ec47f6ff",
    "clang+llvm-14.0.6-arm64-apple-darwin22.3.0.tar.xz": "82f4f7607a16c9aaf7314b945bde6a4639836ec9d2b474ebb3a31dee33e3c15a",
    "clang+llvm-14.0.6-armv7a-linux-gnueabihf.tar.xz": "e50243c191334b80faa0bb18bbadb8afa35cd3d19cb521353c666c1a7ef20173",
    "clang+llvm-14.0.6-powerpc64-ibm-aix-7.2.tar.xz": "38af6625848a8343dc834c2a272ba88028efab575681d913a39a3c6eaa3c11dc",
    "clang+llvm-14.0.6-powerpc64le-linux-rhel-8.4.tar.xz": "4ef7c608ac026bca64149e59fb3abfe0f5212f2be0af12fe6e52c9413b1f7c4a",
    "clang+llvm-14.0.6-powerpc64le-linux-ubuntu-18.04.5.tar.xz": "5eaff8c40a94d36336221f31b413fba500ec240403fa12e99dd49b56b736eeb3",
    "clang+llvm-14.0.6-x86_64-apple-darwin.tar.xz": "e6cc6b8279661fd4452c2847cb8e55ce1e54e1faf4ab497b37c85ffdb6685e7c",
    "clang+llvm-14.0.6-x86_64-linux-gnu-rhel-8.4.tar.xz": "7412026be8bb8f6b4c25ef58c7a1f78ed5ea039d94f0fa633a386de9c60a6942",

    # 15.0.0
    "clang+llvm-15.0.0-aarch64-linux-gnu.tar.xz": "527ed550784681f95ec7a1be8fbf5a24bd03d7da9bf31afb6523996f45670be3",
    "clang+llvm-15.0.0-amd64-pc-solaris2.11.tar.xz": "5b9fd6a30ce6941adf74667d2076a49aa047fa040e3690f7af26c264d4ce58e7",
    "clang+llvm-15.0.0-arm64-apple-darwin21.0.tar.xz": "cfd5c3fa07d7fccea0687f5b4498329a6172b7a15bbc45b547d0ac86bd3452a5",
    "clang+llvm-15.0.0-armv7a-linux-gnueabihf.tar.xz": "58ce8877642fc1399736ffc81bc8ef6244440fc78d72e097a07475b8b25e2bf1",
    "clang+llvm-15.0.0-powerpc64-ibm-aix-7.2.tar.xz": "c5f63401fa88ea96ca7110bd81ead1bf1a2575962e9cc84a6713ec29c02b1c10",
    "clang+llvm-15.0.0-powerpc64le-linux-rhel-8.4.tar.xz": "c94448766b6b92cfc8f35e611308c9680a9ad2177f88d358c2b06e9b108d61bd",
    "clang+llvm-15.0.0-powerpc64le-linux-ubuntu-18.04.6.tar.xz": "6bcedc3d18552732f219c1d0f8c4b0c917ff5f800400a31dabfe8d040cbf1f02",
    "clang+llvm-15.0.0-sparc64-unknown-linux-gnu.tar.xz": "b5a8108040d5d5d69d6106fa89a6cffc71a16a3583b74c1f15c42f392a47a3d9",
    "clang+llvm-15.0.0-sparcv9-sun-solaris2.11.tar.xz": "4354854976355ca6f4ac90231a97121844c4fc9f998c9850527390120c62f01f",
    "clang+llvm-15.0.0-x86_64-apple-darwin.tar.xz": "8fb11e6ada98b901398b2e7b0378a3a59e88c88c754e95d8f6b54613254d7d65",
    "clang+llvm-15.0.0-x86_64-linux-gnu-rhel-8.4.tar.xz": "20b17fabc97b93791098e771adf18013c50eae2e45407f8bfa772883b6027d30",

    # 15.0.1
    "clang+llvm-15.0.1-aarch64-linux-gnu.tar.xz": "201b2f5e537ec88937e0e1b30512453076e73a06ca75edf9939dc0e61b5ccbd1",
    "clang+llvm-15.0.1-arm64-apple-darwin21.0.tar.xz": "858f86d96b5e4880f69f7a583daddbf97ee94e7cffce0d53aa05cba6967f13b8",
    "clang+llvm-15.0.1-armv7a-linux-gnueabihf.tar.xz": "d145a2458a11b3977e48b3fbce66a70d88acd148a44fbf22c0c7a53fb27218bb",
    "clang+llvm-15.0.1-powerpc64-ibm-aix-7.2.tar.xz": "0ee72558ba052815f64f112bdebc6b1684c3cf868ed588936e23ef3bdc52d216",
    "clang+llvm-15.0.1-powerpc64le-linux-rhel-8.4.tar.xz": "30895fae1cdf5cb11ce5fa14fb2e2c16476f1f94c731bf3de398c79be64fed70",
    "clang+llvm-15.0.1-powerpc64le-linux-ubuntu-18.04.5.tar.xz": "e7c427e0590e8c362d0766f9125674e847be9d30986c3d6928be960b30c87e63",
    "clang+llvm-15.0.1-x86_64-apple-darwin.tar.xz": "0b2f1a811e68d011344103274733b7670c15bbe08b2a3a5140ccad8e19d9311e",

    # 15.0.2
    "clang+llvm-15.0.2-aarch64-linux-gnu.tar.xz": "3d0c2b28b0c06ebb9e0ce75e337680403771b28a4b8f065ce608cf2386f97a73",
    "clang+llvm-15.0.2-arm64-apple-darwin21.0.tar.xz": "8c33f807bca56568b7060d0474daf63c8c10ec521d8188ac76362354d313ec58",
    "clang+llvm-15.0.2-powerpc64-ibm-aix-7.2.tar.xz": "7c040d47745923fd8d7fffdd0d37587b021165f1fcc76015e56adbd2f427b251",
    "clang+llvm-15.0.2-powerpc64le-linux-rhel-8.4.tar.xz": "c35d4a36baf1fe2ba790c5813e7d9efa60f892e08f5778d8ba2a1b0092fb9c1c",
    "clang+llvm-15.0.2-powerpc64le-linux-ubuntu-18.04.5.tar.xz": "eeef0714f4ef208f45c757514d1b40114c2ac54bb5885d96b306d50f7725f1cf",
    "clang+llvm-15.0.2-x86_64-apple-darwin.tar.xz": "a37ec6204f555605fa11e9c0e139a251402590ead6e227fc72da193e03883882",
    "clang+llvm-15.0.2-x86_64-unknown-linux-gnu-rhel86.tar.xz": "f48f479e91ee7297ed8306c9d4495015691237cd91cc5330d3e1ee057b0548bd",
    "clang+llvm-15.0.2-x86_64-unknown-linux-gnu-sles15.tar.xz": "8af00fb689459cb6b9af2a427af9d7d99da8f77e1da161fa1dc58164832b3b21",

    # 15.0.3
    "clang+llvm-15.0.3-aarch64-linux-gnu.tar.xz": "fa59fad997025da49b5001d6dc193bb7899e59de6268406b76c4fdbe2b56b7fd",
    "clang+llvm-15.0.3-arm64-apple-darwin21.0.tar.xz": "83603b1258995f2659c3a87f7f62ee9b9c9775d7c7cde92a375c635f7bf73c28",
    "clang+llvm-15.0.3-armv7a-linux-gnueabihf.tar.xz": "6de24c0f778d14228fe15908c687dc7caba280c688d61cc55cbb8d74551385de",
    "clang+llvm-15.0.3-powerpc64-ibm-aix-7.2.tar.xz": "b4fed7e95d33922140e2e080a4b41a7b69b4a7bbcbaa5d896b578d57013639f0",
    "clang+llvm-15.0.3-powerpc64le-linux-rhel-8.4.tar.xz": "5f26ddae25d8d742fc33c85393e4890df37aa16d25d174708de94555b93e3ab3",
    "clang+llvm-15.0.3-powerpc64le-linux-ubuntu-18.04.5.tar.xz": "a5b558266eb0ad11c7db1358763e2ad7194dd7403919a76b444d7a6619ede86a",
    "clang+llvm-15.0.3-x86_64-apple-darwin.tar.xz": "ac668586b2b3d068f1e43520a3ef0b1592e5dc3eff1a4a4b772e29803b428a69",

    # 15.0.4
    "clang+llvm-15.0.4-arm64-apple-darwin21.0.tar.xz": "70e7a6d98fc42d4c36aca1a5b666c57e83ae474df5920382853b9209c829938a",
    "clang+llvm-15.0.4-powerpc64-ibm-aix-7.2.tar.xz": "c0aa0323c0705b93b89667aa8f34ae46e40a6da092295d21895fd7b866ce7f5d",
    "clang+llvm-15.0.4-powerpc64le-linux-rhel-8.4.tar.xz": "4209982861e11852d2248daba76239182d82d1e2165927da12cdbd603d0ec421",
    "clang+llvm-15.0.4-powerpc64le-linux-ubuntu-18.04.5.tar.xz": "0f90e85c21c54d482d3c0ecd073671938d209e5fe8392bb72668cca179b92fd6",
    "clang+llvm-15.0.4-x86_64-apple-darwin.tar.xz": "4c98d891c07c8f6661b233bf6652981f28432cfdbd6f07181114195c3536544b",
    "clang+llvm-15.0.4-x86_64-linux-gnu-rhel-8.4.tar.xz": "2672e88fc9c79ff287a0d0e6dbbaf77fbbea3c12dab39fd733ae9432fbcb7e9e",

    # 15.0.5
    "clang+llvm-15.0.5-arm64-apple-darwin21.0.tar.xz": "0fda3ef24071dffb0c95378be7ed4114999a5a169cd61015e489fd6ee8406809",
    "clang+llvm-15.0.5-powerpc64-ibm-aix-7.2.tar.xz": "eeb3efa22e0bede117474700fd72cf4e4aa0b221401e42e172773740d56635b2",
    "clang+llvm-15.0.5-powerpc64le-linux-rhel-8.4.tar.xz": "b27ec77eea47c1403e66726c97fa2f3c9dd19d40606aa195ff2382f09959253b",
    "clang+llvm-15.0.5-powerpc64le-linux-ubuntu-18.04.5.tar.xz": "760ab1e879438659abeecfed2f08701e996ea02bcdb83d618ccf9390f59f6882",
    "clang+llvm-15.0.5-x86_64-linux-gnu-ubuntu-18.04.tar.xz": "15018e4f45889450b62367acbdc7628556ceba92bd9f6b0544145334d1311cbc",

    # 15.0.6
    "clang+llvm-15.0.6-aarch64-linux-gnu.tar.xz": "8ca4d68cf103da8331ca3f35fe23d940c1b78fb7f0d4763c1c059e352f5d1bec",
    "clang+llvm-15.0.6-arm64-apple-darwin21.0.tar.xz": "32bc7b8eee3d98f72dd4e5651e6da990274ee2d28c5c19a7d8237eb817ce8d91",
    "clang+llvm-15.0.6-armv7a-linux-gnueabihf.tar.xz": "c12e9298f9a9ed3a96342e9ffb2c02146a0cd7535231fef57c7217bd3a36f53b",
    "clang+llvm-15.0.6-powerpc64-ibm-aix-7.2.tar.xz": "6bc1c2fcc8069e28773f6a0d16624160cd6de01b8f15aab27652eedad665d462",
    "clang+llvm-15.0.6-powerpc64le-linux-rhel-8.4.tar.xz": "c26e5563e6ff46a03bc45fe27547c69283b64cba2359ccd3a42f735c995c0511",
    "clang+llvm-15.0.6-powerpc64le-linux-ubuntu-18.04.tar.xz": "7fc9f07ff0fcf191df93fe4adc1da555e43f62fe1d3ddafb15c943f72b1bda17",
    "clang+llvm-15.0.6-x86_64-linux-gnu-ubuntu-18.04.tar.xz": "38bc7f5563642e73e69ac5626724e206d6d539fbef653541b34cae0ba9c3f036",

    # 15.0.7
    "clang+llvm-15.0.7-arm64-apple-darwin22.0.tar.xz": "867c6afd41158c132ef05a8f1ddaecf476a26b91c85def8e124414f9a9ba188d",
    "clang+llvm-15.0.7-powerpc64-ibm-aix-7.2.tar.xz": "6cbc7c7f4395abb9c1a5bdcab3811bd6b1a6c4d08756ba674bfbbd732e2b23ac",
    "clang+llvm-15.0.7-powerpc64le-linux-rhel-8.4.tar.xz": "2163cc934437146dc30810a21a46327ba3983f123c3bea19be316a64135b6414",
    "clang+llvm-15.0.7-powerpc64le-linux-ubuntu-18.04.tar.xz": "19a16d768e15966923b0cbf8fc7dc148c89e316857acd89ad3aff72dcfcd61f4",
    "clang+llvm-15.0.7-x86_64-apple-darwin21.0.tar.xz": "d16b6d536364c5bec6583d12dd7e6cf841b9f508c4430d9ee886726bd9983f1c",

    # 16.0.0
    "clang+llvm-16.0.0-aarch64-linux-gnu.tar.xz": "b750ba3120e6153fc5b316092f19b52cf3eb64e19e5f44bd1b962cb54a20cf0a",
    "clang+llvm-16.0.0-amd64-pc-solaris2.11.tar.xz": "b637b7da383d3417ac4862342911cb467fba2ec00f48f163eb8308f2bbb9b7ad",
    "clang+llvm-16.0.0-amd64-unknown-freebsd13.tar.xz": "c4fe6293349b3ab7d802793103d1d44f58831884e63ff1b40ce29c3e7408257b",
    "clang+llvm-16.0.0-arm64-apple-darwin22.0.tar.xz": "2041587b90626a4a87f0de14a5842c14c6c3374f42c8ed12726ef017416409d9",
    "clang+llvm-16.0.0-powerpc64-ibm-aix-7.2.tar.xz": "e51209eeea3c3db41084d8625ab3357991980831e0b641d633ec23e9d858333f",
    "clang+llvm-16.0.0-powerpc64le-linux-rhel-8.4.tar.xz": "eb56949af9a83a12754f7cf254886d30c4be8a1da4dd0f27db790a7fcd35a3bf",
    "clang+llvm-16.0.0-powerpc64le-linux-ubuntu-18.04.tar.xz": "ae34b037cde14f19c3c431de5fc04e06fa43d2cce3f8d44a63659b48afdf1f7a",
    "clang+llvm-16.0.0-sparc64-unknown-linux-gnu.tar.xz": "a2627fcb6d97405b38c9e4c17ccfdc5d61fdd1bee742dcce0726ed39e2dcd92c",
    "clang+llvm-16.0.0-sparcv9-sun-solaris2.11.tar.xz": "45c2ac0c10c3876332407a1ea893dccbde77a490f4a9b54a00e4881681a3c5ea",
    "clang+llvm-16.0.0-x86_64-linux-gnu-ubuntu-18.04.tar.xz": "2b8a69798e8dddeb57a186ecac217a35ea45607cb2b3cf30014431cff4340ad1",

    # 16.0.1
    "clang+llvm-16.0.1-aarch64-linux-gnu.tar.xz": "83e38451772120b016432687c0a3aab391808442b86f54966ef44c73a26280ac",
    "clang+llvm-16.0.1-amd64-unknown-freebsd13.tar.xz": "970359de2a1a09a93a9e1cf3405e5758dfe463567b20a168f9156bd72b7f8ac6",
    "clang+llvm-16.0.1-arm64-apple-darwin22.0.tar.xz": "cb487fa991f047dc79ae36430cbb9ef14621c1262075373955b1d97215c75879",
    "clang+llvm-16.0.1-powerpc64-ibm-aix-7.2.tar.xz": "c56d9cf643b7f39e40436e55b59b3bd88057ec0fa084bd8e06ac17fb20ea2a21",
    "clang+llvm-16.0.1-powerpc64le-linux-rhel-8.4.tar.xz": "c89a9af64a35ee58ef4eac7b52c173707140dc7eac6839ff254b656de8eb6c3c",
    "clang+llvm-16.0.1-powerpc64le-linux-ubuntu-20.04.tar.xz": "08b39f9e6c19086aaf029d155c42a4db96ce662f84d6e89d8c9037d3baeee036",

    # 16.0.2
    "clang+llvm-16.0.2-aarch64-linux-gnu.tar.xz": "de89d138cfb17e2d81fdaca2f9c5e0c042014beea6bcacde7f27db40b69c0bdc",
    "clang+llvm-16.0.2-amd64-unknown-freebsd13.tar.xz": "0cd92b6a84e7477aa8070465f01eec8198e0b1e38d1b6da8c61859a633ec9a71",
    "clang+llvm-16.0.2-arm64-apple-darwin22.0.tar.xz": "539861297b8aa6be8e89bf68268b07d79d7a1fde87f4b98f123709f13933f326",
    "clang+llvm-16.0.2-powerpc64-ibm-aix-7.2.tar.xz": "8c9cbf29b261f1af905f41032b446fd78bd560b549ab31d05a16d0cc972df23d",
    "clang+llvm-16.0.2-powerpc64le-linux-rhel-8.4.tar.xz": "fe21023b64d2298d65fea0f4832a27a9948121662b54a8c8ce8a9331c4039c36",
    "clang+llvm-16.0.2-x86_64-linux-gnu-ubuntu-22.04.tar.xz": "9530eccdffedb9761f23cbd915cf95d861b1d95f340ea36ded68bd6312af912e",

    # 16.0.3
    "clang+llvm-16.0.3-aarch64-linux-gnu.tar.xz": "315fd821ddb3e4b10c4dfabe7f200d1d17902b6a5ccd5dd665a0cd454bca379f",
    "clang+llvm-16.0.3-arm64-apple-darwin22.0.tar.xz": "b9068eee1cf1e17848241ea581a2abe6cb4a15d470ec515c100f8b52e4c6a7cb",
    "clang+llvm-16.0.3-powerpc64-ibm-aix-7.2.tar.xz": "f0372ea5b665ca1b8524b933b84ccbe59e9441537388815b24323aa4aab7db2f",
    "clang+llvm-16.0.3-powerpc64le-linux-rhel-8.4.tar.xz": "9804721c746d74a85ce935d938509277af728fad1548835f539660ff1380e04d",
    "clang+llvm-16.0.3-x86_64-linux-gnu-ubuntu-22.04.tar.xz": "638d32fd0032f99bafaab3bae63a406adb771825a02b6b7da119ee7e71af26c6",

    # 16.0.4
    "clang+llvm-16.0.4-aarch64-linux-gnu.tar.xz": "2e0b5b20d21ff80dea9f31d3f7636e458028ad0d5ee0bda42608fa8744ea3a12",
    "clang+llvm-16.0.4-amd64-unknown-freebsd13.tar.xz": "cf9d73bcf05b8749c7f3efbe86654b8fe0209f28993eafe26c27eb85885593f7",
    "clang+llvm-16.0.4-arm64-apple-darwin22.0.tar.xz": "429b8061d620108fee636313df55a0602ea0d14458c6d3873989e6b130a074bd",
    "clang+llvm-16.0.4-armv7a-linux-gnueabihf.tar.xz": "e3fafbb5813650cdbfb191005fa8a7b1f036fbadff171e05b32d06015e1feb46",
    "clang+llvm-16.0.4-powerpc64-ibm-aix-7.2.tar.xz": "af8691731ddd4142c53d9aeb2ad2c4281f4ca9819c5630e7ccade40f39dc4ee5",
    "clang+llvm-16.0.4-powerpc64le-linux-rhel-8.4.tar.xz": "fe99951300ae7f1877f00531dc5a2f5f00572fa236be6d1323902ea6aeb0a496",
    "clang+llvm-16.0.4-x86_64-linux-gnu-ubuntu-22.04.tar.xz": "fd464333bd55b482eb7385f2f4e18248eb43129a3cda4c0920ad9ac3c12bdacf",

    # 16.0.5
    "clang+llvm-16.0.5-aarch64-linux-gnu.tar.xz": "c427d4fa5cd21a11d9fea55ae60ad2e7230ad8411f7a0dea867273f2a1b74891",
    "clang+llvm-16.0.5-amd64-unknown-freebsd13.tar.xz": "c52d693584d4f86d972acb52be5d14d13ccd815c68ca22114e46829219da3734",
    "clang+llvm-16.0.5-arm64-apple-darwin22.0.tar.xz": "1aed0787417dd915f0101503ce1d2719c8820a2c92d4a517bfc4044f72035bcc",
    "clang+llvm-16.0.5-powerpc64-ibm-aix-7.2.tar.xz": "5649575b499deff1470dd1f3baacbee445bf2789de266135d81024572efc54f0",
    "clang+llvm-16.0.5-powerpc64le-linux-rhel-8.7.tar.xz": "8f2588dabcc2515e860733c2001fb81774aa2d2bccad153f064cfb886df2d065",

    # 16.0.6
    "clang+llvm-16.0.6-aarch64-linux-gnu.tar.xz": "283e904048425f05798a98f1b288ae0d28ce75eb1049e0837f959e911369945b",
    "clang+llvm-16.0.6-powerpc64le-linux-rhel-8.7.tar.xz": "1f8d73c342efc82618bd8d58fa8855bc7e70bd2a6ed9646065aabfa4b468e82d",

    # 17.0.1
    "clang+llvm-17.0.1-aarch64-linux-gnu.tar.xz": "d2eaca72ce3aab0b343e01b2233303628ff43a43a6107dca1aa8d3039da847f5",
    "clang+llvm-17.0.1-amd64-pc-solaris2.11.tar.xz": "153b8b650705390cc3b4ff739b061f5bff87542531c002c039d52c00781559f7",
    "clang+llvm-17.0.1-arm64-apple-darwin22.0.tar.xz": "d5678bc475c42c3ab7c0ee35ebd95534d81b6816507cfc9e42d86136d8315ebc",
    "clang+llvm-17.0.1-final_powerpc64-ibm-aix-7.2.tar.xz": "f5d9bf5822a775d4b10e7af035076e1779983dee1b05b3f57af2674231bcf678",
    "clang+llvm-17.0.1-powerpc64le-linux-rhel-8.8.tar.xz": "937394cd44c5eb81aae8d1c66b6d3b930ebd2b013ac6493d17f33f5083281d37",
    "clang+llvm-17.0.1-sparc64-unknown-linux-gnu.tar.xz": "0ab5f6a9b19ec968628d987d9430a033801c78bee65fbf40c72da660ff401f4d",
    "clang+llvm-17.0.1-sparcv9-sun-solaris2.11.tar.xz": "a69d47bb1397766a87fcdef28260fc664fdf9b6e1f7c56792939baf8513c1694",

    # 17.0.2
    "clang+llvm-17.0.2-aarch64-linux-gnu.tar.xz": "b08480f2a77167556907869065b0e0e30f4d6cb64ecc625d523b61c22ff0200f",
    "clang+llvm-17.0.2-amd64-pc-solaris2.11.tar.xz": "8e98c6015202575407f5580bed9a9b58d3bdc3e5d64e39289189b491949b957f",
    "clang+llvm-17.0.2-arm64-apple-darwin22.0.tar.xz": "dfb3226b3e16f5b8d3882f3ff0e8ebf40b26dd1e97d879197430b930d773ea84",
    "clang+llvm-17.0.2-powerpc64-ibm-aix-7.2.tar.xz": "c0175b48bf72c621316f3fc7ec4662163d4e17718b179f967d75149d7cfeee80",
    "clang+llvm-17.0.2-powerpc64le-linux-rhel-8.8.tar.xz": "ef19116996a1966a4fa6e261c86eef7b807e5f39a963dc914b5547976336ab1b",
    "clang+llvm-17.0.2-sparc64-unknown-linux-gnu.tar.xz": "950d1ef440f17e29c4201450ad619d3b4a37a0bbf15f19ce03195e0b4da7d73f",
    "clang+llvm-17.0.2-sparcv9-sun-solaris2.11.tar.xz": "3702914668b5758817374271fa8a41fe67c77b2e86f17706c9d6906f250de6ae",
    "clang+llvm-17.0.2-x86_64-linux-gnu-ubuntu-22.04.tar.xz": "df297df804766f8fb18f10a188af78e55d82bb8881751408c2fa694ca19163a8",

    # 17.0.3
    "clang+llvm-17.0.3-aarch64-linux-gnu.tar.xz": "289da98e4cbc157153e987ff24ce835717a36cfab03ecd03bf359378ee4ae9d7",
    "clang+llvm-17.0.3-arm64-apple-darwin22.0.tar.xz": "da452a1aa33954c123d5264bd849ebc572a28e8511b868b43e82d6960fda60d7",
    "clang+llvm-17.0.3-powerpc64-ibm-aix-7.2.tar.xz": "86b05883c17ddb4b7e9ad6a6a88e78311c117fdc03415fa47293e12e6e2810ff",
    "clang+llvm-17.0.3-powerpc64le-linux-rhel-8.8.tar.xz": "fcba4ac2a717762ff1b5fe482a811648837d7dc7bf7b654702c80f2fa044d07d",

    # 17.0.4
    "clang+llvm-17.0.4-aarch64-linux-gnu.tar.xz": "18b326b3e17168fc423726b5059b4d55b6070d49408e51440ad3fca2ebb37779",
    "clang+llvm-17.0.4-arm64-apple-darwin22.0.tar.xz": "5d514fa64a290dca53288ce859e6ec59a0b48198b3a5b27ca53b6fe80a977b8d",
    "clang+llvm-17.0.4-powerpc64-ibm-aix-7.2.tar.xz": "54d4d6b91624597e0c0b15264c4c8e57092f521247b87ba6f1297db339ac6e2b",
    "clang+llvm-17.0.4-powerpc64le-linux-rhel-8.8.tar.xz": "2e3ac8b7288ed5d5c3549e457332bbf3c913022fdd7cfbe13fde46448f76d136",
    "clang+llvm-17.0.4-x86_64-linux-gnu-ubuntu-22.04.tar.xz": "6b45be6c0483b7ee3f63981678093b731fd9f4ea6987b4ceb6efde21890ffca7",

    # 17.0.5
    "clang+llvm-17.0.5-aarch64-linux-gnu.tar.xz": "ee12126c404d42a0723ff3a4449470b5570fe5ce610be9d9baee88a6d27701d2",
    "clang+llvm-17.0.5-arm64-apple-darwin22.0.tar.xz": "6c9aa227800d30d39c28dadbd72c15442e0d9b6813efb2aaa66a478630b7f0c6",
    "clang+llvm-17.0.5-powerpc64-ibm-aix-7.2.tar.xz": "b5da095901fe604f562363cf9611d6ca73e13d81831a96518823d690babc608f",
    "clang+llvm-17.0.5-powerpc64le-linux-rhel-8.8.tar.xz": "11aace89d7881b694a05d1e93de3c78a31e141d0df1401491d67f73020bc3df2",
    "clang+llvm-17.0.5-x86_64-linux-gnu-ubuntu-22.04.tar.xz": "5a3cedecd8e2e8663e84bec2f8e5522b8ea097f4a8b32637386f27ac1ca01818",

    # 17.0.6
    "clang+llvm-17.0.6-aarch64-linux-gnu.tar.xz": "6dd62762285326f223f40b8e4f2864b5c372de3f7de0731cb7cd55ca5287b75a",
    "clang+llvm-17.0.6-amd64-pc-solaris2.11.tar.xz": "8feb660750a4d24b18d8e894fbccf26bd0dfbc92581d202ec9057f00f3fbf232",
    "clang+llvm-17.0.6-arm64-apple-darwin22.0.tar.xz": "1264eb3c2a4a6d5e9354c3e5dc5cb6c6481e678f6456f36d2e0e566e9400fcad",
    "clang+llvm-17.0.6-powerpc64-ibm-aix-7.2.tar.xz": "3aeda4bb5808db2e47bde60cc49b15b869114e3681092413f7b297345d2e13ce",
    "clang+llvm-17.0.6-powerpc64le-linux-rhel-8.8.tar.xz": "04e18072797920c2b5e9bdf0c3ee9e5a61adf76bd5ffeb438fafd9e32fc48b62",
    "clang+llvm-17.0.6-sparcv9-sun-solaris2.11.tar.xz": "b7df7b383679af98640640f88114f461f38a6efdfe7c369692b0675751ac2773",
    "clang+llvm-17.0.6-x86_64-linux-gnu-ubuntu-22.04.tar.xz": "884ee67d647d77e58740c1e645649e29ae9e8a6fe87c1376be0f3a30f3cc9ab3",

    # 18.1.0
    "clang+llvm-18.1.0-aarch64-linux-gnu.tar.xz": "32faaad5b6e072d763a603f7c51e4ee63e2d82c16e945524a539df84e3f2b058",
    "clang+llvm-18.1.0-amd64-pc-solaris2.11.tar.xz": "c352b81dd6add029e3def54a7b90387bb1df15f76497adac0b9f305694eb2d8c",
    "clang+llvm-18.1.0-powerpc64-ibm-aix-7.2.tar.xz": "cc9bcf2b2132c158a71f7f3971d105454131701c25767f97e977c568418aff89",
    "clang+llvm-18.1.0-powerpc64le-linux-rhel-8.8.tar.xz": "730c40a0c79d89ca8875c2004fd49180e9b65585b24f68728232b06b3d8bda32",
    "clang+llvm-18.1.0-sparcv9-sun-solaris2.11.tar.xz": "e871f472ceafbe0197cff81d7240552e45e55ead00fe82f4fb326af32bbfb657",
    "clang+llvm-18.1.0-sparcv9-unknown-linux-gnu.tar.xz": "0f6d94d9e3eccb5596def41e48b3f8a400f27edc2374e6fc53d0b6baea0d79b3",
    "clang+llvm-18.1.0-x86_64-pc-windows-msvc.tar.xz": "d128c0f5f7831c77d549296a910fc9972407ff028b720fb628ffa837ed7ff04e",

    # 18.1.1
    "clang+llvm-18.1.1-aarch64-linux-gnu.tar.xz": "6815ef3c314566605f90cff7922ff3ef5a6eaaf854604e4add6a170e6e98389f",
    "clang+llvm-18.1.1-powerpc64-ibm-aix-7.2.tar.xz": "c900418e781d0de1f316fcce50ffeca903fa15d97df0dd90f6ac4bd2b43105d4",
    "clang+llvm-18.1.1-powerpc64le-linux-rhel-8.8.tar.xz": "7415429a0c0eceeacedc00b3f99f9a869909682fab130c2e514f240379539741",
    "clang+llvm-18.1.1-x86_64-pc-windows-msvc.tar.xz": "79ea242c0fbd66c632ed3aaebf6f821c1e4c03140497c67ea750443eb36bfc5d",

    # 18.1.2
    "clang+llvm-18.1.2-aarch64-linux-gnu.tar.xz": "aa9d6c6e70cbe2344be1f4b780525a9a4feb70a6e4fa46ea67822f0e7f839c21",
    "clang+llvm-18.1.2-amd64-pc-solaris2.11.tar.xz": "83ca7644b5eebf5ac55014e628d0bbe685a79416d70a0d80d24ece0ddfc05c6d",
    "clang+llvm-18.1.2-powerpc64-ibm-aix-7.2.tar.xz": "ad7351206905f61933be5937017fc454995d287346f7f0325c48c4552803af87",
    "clang+llvm-18.1.2-powerpc64le-linux-rhel-8.8.tar.xz": "0dc4831dab74f47691dab934a52a055ea8fae6bfeec2ed5261991146b38f1cf3",
    "clang+llvm-18.1.2-sparcv9-sun-solaris2.11.tar.xz": "b719027e8423296f06375ee151652623b0a1df46848dac0bb2614210e5bd233e",
    "clang+llvm-18.1.2-x86_64-pc-windows-msvc.tar.xz": "0f3df344d9342905ba5ee6b6f669468d9c105a5812b794e7898d7b39780ce3ad",

    # 18.1.3
    "clang+llvm-18.1.3-aarch64-linux-gnu.tar.xz": "249418a3b85326ef144349491cbcaf5bf60966d99e9fabbcd1b79edd27d9a722",
    "clang+llvm-18.1.3-armv7a-linux-gnueabihf.tar.gz": "130f878a3e58bf8d46ddaf70b35502176df381ba467db8bbd14fb0b7184ff3c8",
    "clang+llvm-18.1.3-powerpc64-ibm-aix-7.2.tar.xz": "5123eaa520061794566325e65778e54d8dff47075e859486b8cf860a62e9da62",
    "clang+llvm-18.1.3-powerpc64le-linux-rhel-8.8.tar.xz": "a89b38c9cb0fa94873322ddbf57049f3e2615a6fb0ce2769d53ead4806c80797",

    # 18.1.4
    "clang+llvm-18.1.4-aarch64-linux-gnu.tar.xz": "8c2f4d1606d24dc197a590acce39453abe7a302b9b92e762108f9b5a9701b1df",
    "clang+llvm-18.1.4-armv7a-linux-gnueabihf.tar.gz": "f7b32c8e02e5821ed6d0062f3b35920796127759d3a14b32928227b7270ce85f",
    "clang+llvm-18.1.4-powerpc64-ibm-aix-7.2.tar.xz": "92fe70e845c8d9a881151d33ac3fbab5918a4bd5f9a49605c8e39ef3e66ce32b",
    "clang+llvm-18.1.4-powerpc64le-linux-rhel-8.8.tar.xz": "1ebc36b1bc5c6d7238b33bd60d6d6bf6f7880241481ceb54ebf5df44419ce176",
    "clang+llvm-18.1.4-x86_64-linux-gnu-ubuntu-18.04.tar.xz": "1607375b4aa2aec490b6db51846a04b265675a87e925bcf5825966401ff9b0b1",
    "clang+llvm-18.1.4-x86_64-pc-windows-msvc.tar.xz": "4eb5b0c724e79ad7cf4cdc289d5be633d46963b67efce212c75f3742ce0e345e",

    # 18.1.5
    "clang+llvm-18.1.5-aarch64-linux-gnu.tar.xz": "d597fa5f49c6d9f102f042a3ad83e2b5fd1d0597948012a668f902164db9546c",
    "clang+llvm-18.1.5-armv7a-linux-gnueabihf.tar.gz": "8defe9bb0212069e4dbb67fb5f48967b33e6bba0a918f08df28dcaf20b507f28",
    "clang+llvm-18.1.5-powerpc64-ibm-aix-7.2.tar.xz": "9560cefa86fbf473c1c0fcf4f4d1894733135e241ff3114421b00cee4fc1bfbf",
    "clang+llvm-18.1.5-powerpc64le-linux-rhel-8.8.tar.xz": "10c85b809bcf75656ccbd264def39868d08aa30d58ec5b9b463aefed4127f660",
    "clang+llvm-18.1.5-x86_64-pc-windows-msvc.tar.xz": "7027f03bcab87d8a72fee35a82163b0730a9c92f5160373597de95010f722935",
}

# Note: Unlike the user-specified llvm_mirror attribute, the URL prefixes in
# this map are not immediately appended with "/". This is because LLVM prebuilt
# URLs changed when they switched to hosting the files on GitHub as of 10.0.0.
_llvm_distributions_base_url = {
    "6.0.0": "https://releases.llvm.org/",
    "6.0.1": "https://releases.llvm.org/",
    "7.0.0": "https://releases.llvm.org/",
    "8.0.0": "https://releases.llvm.org/",
    "8.0.1": "https://releases.llvm.org/",
    "9.0.0": "https://releases.llvm.org/",
    "10.0.0": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "10.0.1": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "11.0.0": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "11.0.1": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "11.1.0": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "12.0.0": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "12.0.1": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "13.0.0": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "13.0.1": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "14.0.0": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "14.0.1": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "14.0.2": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "14.0.3": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "14.0.4": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "14.0.5": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "14.0.6": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "15.0.0": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "15.0.1": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "15.0.2": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "15.0.3": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "15.0.4": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "15.0.5": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "15.0.6": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "15.0.7": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "16.0.0": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "16.0.1": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "16.0.2": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "16.0.3": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "16.0.4": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "16.0.5": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "16.0.6": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "17.0.1": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "17.0.2": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "17.0.3": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "17.0.4": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "17.0.5": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "17.0.6": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "18.1.0": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "18.1.1": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "18.1.2": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "18.1.3": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "18.1.4": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
    "18.1.5": "https://github.com/llvm/llvm-project/releases/download/llvmorg-",
}

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
