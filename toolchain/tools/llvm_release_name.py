#!/usr/bin/env python3
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
"""LLVM pre-built distribution file names."""

import platform
import sys

_known_distros = ["freebsd", "suse", "ubuntu", "arch", "manjaro", "debian", "fedora", "centos", "amzn"]

def _major_llvm_version(llvm_version):
    return int(llvm_version.split(".")[0])

def _darwin(llvm_version):
    major_llvm_version = _major_llvm_version(llvm_version)
    suffix = "darwin-apple" if major_llvm_version == 9 else "apple-darwin"
    return "clang+llvm-{llvm_version}-x86_64-{suffix}.tar.xz".format(
        llvm_version=llvm_version, suffix=suffix)

def _windows(llvm_version):
    if platform.machine().endswith('64'):
        win_arch = "win64"
    else:
        win_arch = "win32"

    return "LLVM-{llvm_version}-{win_arch}.exe".format(
        llvm_version=llvm_version,
        win_arch=win_arch)

def _linux(llvm_version):
    arch = platform.machine()

    release_file_path = "/etc/os-release"
    with open(release_file_path) as release_file:
        lines = release_file.readlines()
        info = dict()
        for line in lines:
            line = line.strip()
            if not line:
                continue
            [key, val] = line.split('=', 1)
            info[key] = val
    if "ID" not in info:
        sys.exit("Could not find ID in /etc/os-release.")
    distname = info["ID"].strip('\"')

    if distname not in _known_distros:
        for distro in info["ID_LIKE"].strip('\"').split(' '):
            if distro in _known_distros:
                distname = distro
                break

    version = None
    if "VERSION_ID" in info:
        version = info["VERSION_ID"].strip('"')

    major_llvm_version = _major_llvm_version(llvm_version)

    # NOTE: Many of these systems are untested because I do not have access to them.
    # If you find this mapping wrong, please send a Pull Request on Github.
    if arch in ["aarch64", "armv7a", "mips", "mipsel"]:
        os_name = "linux-gnu"
    elif distname == "freebsd":
        os_name = "unknown-freebsd-%s" % version
    elif distname == "suse":
        os_name = "linux-sles%s" % version
    elif distname == "ubuntu" and version.startswith("14.04"):
        os_name = "linux-gnu-ubuntu-14.04"
    elif (distname == "ubuntu" and version.startswith("20.04")) or (distname == "linuxmint" and version.startswith("20")):
        if major_llvm_version < 11:
            # There is no binary packages specifically for 20.04, but those for 18.04 works on
            # 20.04
            os_name = "linux-gnu-ubuntu-18.04"
        else:
            # release 11.0.0 started providing packaging for ubuntu 20
            os_name = "linux-gnu-ubuntu-20.04"
    elif (distname == "ubuntu" and version.startswith("18.04")) or (distname == "linuxmint" and version.startswith("19")):
        os_name = "linux-gnu-ubuntu-18.04"
    elif (distname == "ubuntu" and version.startswith("20")) or (distname == "pop" and version.startswith("20")):
        # use ubuntu 18.04 clang LLVM release for ubuntu 20.04
        os_name = "linux-gnu-ubuntu-18.04"
    elif distname in ["ubuntu", "manjaro"] or (distname == "linuxmint" and version.startswith("18")):
        os_name = "linux-gnu-ubuntu-16.04"
    elif distname == "debian" and (version is None or int(version) == 10):
        os_name = "linux-gnu-ubuntu-18.04"
    elif distname == "debian" and int(version) == 9 and major_llvm_version >= 7:
        os_name = "linux-gnu-ubuntu-16.04"
    elif distname == "debian" and int(version) == 8 and major_llvm_version < 7:
        os_name = "linux-gnu-debian8"
    elif ((distname == "fedora" and int(version) >= 27) or
          (distname == "centos" and int(version) >= 7)) and major_llvm_version < 7:
        os_name = "linux-gnu-Fedora27"
    elif distname == "centos" and major_llvm_version >= 7:
        os_name = "linux-sles11.3"
    elif distname == "fedora" and major_llvm_version >= 7:
        os_name = "linux-gnu-ubuntu-18.04"
    elif distname == "arch" and major_llvm_version >= 11:
        os_name = "linux-gnu-ubuntu-20.04"
    elif distname == "arch" and major_llvm_version >= 10:
        os_name = "linux-gnu-ubuntu-18.04"
    elif distname == "arch" and major_llvm_version >= 7:
        os_name = "linux-gnu-ubuntu-16.04"
    elif distname == "amzn":
        # Based on the ID_LIKE field, sles seems like the closest available
        # distro for which LLVM releases are widely available.
        if major_llvm_version >= 11:
            os_name = "linux-sles12.4"
        else:
            os_name = "linux-sles11.3"
    else:
        sys.exit("Unsupported linux distribution and version: %s, %s" % (distname, version))

    return "clang+llvm-{llvm_version}-{arch}-{os_name}.tar.xz".format(
        llvm_version=llvm_version,
        arch=arch,
        os_name=os_name)

def main():
    """Prints the pre-built distribution file name."""

    if len(sys.argv) != 2:
        sys.exit("Usage: %s llvm_version" % sys.argv[0])

    llvm_version = sys.argv[1]

    system = platform.system()
    if system == "Darwin":
        print(_darwin(llvm_version))
        sys.exit()

    if system == "Windows":
        print(_windows(llvm_version))
        sys.exit()

    if system == "Linux":
        print(_linux(llvm_version))
        sys.exit()

    sys.exit("Unsupported system: %s" % system)

if __name__ == '__main__':
    main()
