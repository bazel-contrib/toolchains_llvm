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

import host_os_key

def _major_llvm_version(llvm_version):
    return int(llvm_version.split(".")[0])

def _minor_llvm_version(llvm_version):
    return int(llvm_version.split(".")[1])

def _patch_llvm_version(llvm_version):
    return int(llvm_version.split(".")[2])

def _darwin(llvm_version, arch):
    major_llvm_version = _major_llvm_version(llvm_version)
    suffix = "darwin-apple" if major_llvm_version == 9 else "apple-darwin"
    return "clang+llvm-{llvm_version}-{arch}-{suffix}.tar.xz".format(
        llvm_version=llvm_version, arch=arch, suffix=suffix)

def _windows(llvm_version, arch):
    if arch.endswith('64'):
        win_arch = "win64"
    else:
        win_arch = "win32"

    return "LLVM-{llvm_version}-{win_arch}.exe".format(
        llvm_version=llvm_version,
        win_arch=win_arch)

def _ubuntu_osname(arch, version, major_llvm_version, llvm_version):
    if arch == "powerpc64le":
        if major_llvm_version > 11:
            return "linux-gnu-ubuntu-18.04"
        else:
            return "linux-gnu-ubuntu-16.04"

    os_name = "linux-gnu-ubuntu-16.04"

    is_llvm_major_release = (_minor_llvm_version(llvm_version) == 0) and (_patch_llvm_version(llvm_version) == 0)
    major_ubuntu_version = int(version.split(".")[0])
    if major_ubuntu_version >= 20:
        if (not version.startswith("20.04")) and (llvm_version in ["11.0.1", "11.1.0"]):
            os_name = "linux-gnu-ubuntu-20.10"
        elif is_llvm_major_release and (major_llvm_version >= 14):
            os_name = "linux-gnu-ubuntu-18.04"
        elif is_llvm_major_release and (major_llvm_version >= 11):
            os_name = "linux-gnu-ubuntu-20.04"
        elif is_llvm_major_release and (major_llvm_version >= 8):
            os_name = "linux-gnu-ubuntu-18.04"
        else:
            # There is no binary packages specifically for 20.04, but those for 16.04 works on
            # 20.04
            os_name = "linux-gnu-ubuntu-16.04"
    elif major_ubuntu_version >= 18:
        if is_llvm_major_release and (major_llvm_version >= 14):
            os_name = "linux-gnu-ubuntu-18.04"
        elif is_llvm_major_release and (major_llvm_version >= 11):
            # There is no binary packages specifically for 18.04, but those for 16.04 works on
            # 18.04
            os_name = "linux-gnu-ubuntu-16.04"
        elif is_llvm_major_release and (major_llvm_version >= 8):
            os_name = "linux-gnu-ubuntu-18.04"
        else:
            # There is no binary packages specifically for 18.04, but those for 16.04 works on
            # 18.04
            os_name = "linux-gnu-ubuntu-16.04"

    return os_name

def _linux(llvm_version, distname, version, arch):
    major_llvm_version = _major_llvm_version(llvm_version)

    # NOTE: Many of these systems are untested because I do not have access to them.
    # If you find this mapping wrong, please send a Pull Request on Github.
    if arch in ["aarch64", "armv7a", "mips", "mipsel"]:
        os_name = "linux-gnu"
    elif distname == "freebsd":
        os_name = "unknown-freebsd-%s" % version
    elif distname == "suse":
        os_name = _resolve_version_for_suse(major_llvm_version, llvm_version)
    elif distname == "ubuntu":
        os_name = _ubuntu_osname(arch, version, major_llvm_version, llvm_version)
    elif ((distname in ["linuxmint", "pop"]) and (version.startswith("21") or version.startswith("20") or version.startswith("19"))):
        os_name = _ubuntu_osname(arch, "20.04", major_llvm_version, llvm_version)
    elif distname in ["manjaro"] or (distname == "linuxmint" and version.startswith("18")):
        os_name = "linux-gnu-ubuntu-16.04"
    elif distname == "debian":
        int_version = None
        try:
            int_version = int(version)
        except ValueError:
            pass
        if int_version is None or int_version >= 9:
            os_name = _ubuntu_osname(arch, "20.04", major_llvm_version, llvm_version)
        elif int_version == 8 and major_llvm_version < 7:
            os_name = "linux-gnu-debian8"
    elif ((distname == "fedora" and int(version) >= 27) or
          (distname == "centos" and int(version) >= 7)) and major_llvm_version < 7:
        os_name = "linux-gnu-Fedora27"
    elif distname == "centos" and major_llvm_version >= 7:
        os_name = _resolve_version_for_suse(major_llvm_version, llvm_version)
    elif distname == "fedora" and major_llvm_version >= 7:
        os_name = _ubuntu_osname(arch, "20.04", major_llvm_version, llvm_version)
    elif distname == "arch":
        os_name = _ubuntu_osname(arch, "20.04", major_llvm_version, llvm_version)
    elif distname == "amzn":
        # Based on the ID_LIKE field, sles seems like the closest available
        # distro for which LLVM releases are widely available.
        os_name = _resolve_version_for_suse(major_llvm_version, llvm_version)
    elif distname == "raspbian":
        arch = "armv7a"
        os_name = "linux-gnueabihf"
    else:
        sys.exit("Unsupported linux distribution and version: %s, %s" % (distname, version))

    return "clang+llvm-{llvm_version}-{arch}-{os_name}.tar.xz".format(
        llvm_version=llvm_version,
        arch=arch,
        os_name=os_name)

def _resolve_version_for_suse(major_llvm_version, llvm_version):
    minor_llvm_version = _minor_llvm_version(llvm_version)
    if major_llvm_version < 10:
        os_name = "linux-sles11.3"
    elif major_llvm_version == 10 and minor_llvm_version == 0:
        os_name = "linux-sles11.3"
    elif major_llvm_version < 13 or (major_llvm_version == 14 and minor_llvm_version == 0):
        os_name = "linux-sles12.4"
    else:
        os_name = _ubuntu_osname("x86_64", "20.04", major_llvm_version, llvm_version)
    return os_name

def main():
    """Prints the pre-built distribution file name."""

    if len(sys.argv) != 2:
        sys.exit("Usage: %s llvm_version" % sys.argv[0])

    llvm_version = sys.argv[1]

    os, version, arch = host_os_key.os_version_arch()

    if os == "darwin":
        print(_darwin(llvm_version, arch))
    elif os == "windows":
        print(_windows(llvm_version, arch))
    else:
        print(_linux(llvm_version, os, version, arch))

if __name__ == '__main__':
    main()
