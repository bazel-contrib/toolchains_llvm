#!/usr/bin/env python3
# Copyright 2022 The Bazel Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
#!/usr/bin/env python3
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Host OS name, version and architecture."""

import platform
import sys


_known_distros = ["freebsd", "suse", "ubuntu", "arch", "manjaro", "debian", "fedora", "centos", "amzn", "raspbian", "pop"]


def _linux_dist():
    """Return Linux distname and version."""

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

    version = ""
    if "VERSION_ID" in info:
        version = info["VERSION_ID"].strip('"')

    return distname, version


def os_version_arch():
    """Return OS name, version and platform architecture."""

    system = platform.system()
    version = ""
    arch = platform.machine()

    if system == "Darwin":
        return "darwin", "", arch

    if system == "Windows":
        return "windows", "", arch

    if system == "Linux":
        distname, version = _linux_dist()
        return distname, version, arch

    sys.exit("Unsupported system: %s" % system)


def main():
    """Prints the OS name, version, and architecture."""
    os, version, arch = os_version_arch()
    if version == "":
        print("%s-%s" % (os, arch))
    else:
        print("%s-%s-%s" % (os, version, arch))


if __name__ == "__main__":
    main()
