load(
    "//toolchain/internal:common.bzl",
    _os_version_arch = "os_version_arch",
)

def _major_llvm_version(llvm_version):
    return int(llvm_version.split(".")[0])

def _minor_llvm_version(llvm_version):
    return int(llvm_version.split(".")[1])

def _patch_llvm_version(llvm_version):
    return int(llvm_version.split(".")[2])

def _darwin_apple_suffix(llvm_version, arch):
    major_llvm_version = _major_llvm_version(llvm_version)
    patch_llvm_version = _patch_llvm_version(llvm_version)
    if major_llvm_version == 9:
        return "darwin-apple"
    elif major_llvm_version >= 15:
        if arch == "arm64":
            if major_llvm_version == 15 and patch_llvm_version <= 6:
                return "apple-darwin21.0"
            else:
                return "apple-darwin22.0"
        else:
            return "apple-darwin21.0"
    else:
        return "apple-darwin"

def _darwin(llvm_version, arch):
    if arch == "aarch64":
        arch = "arm64"
    suffix = _darwin_apple_suffix(llvm_version, arch)
    return "clang+llvm-{llvm_version}-{arch}-{suffix}.tar.xz".format(
        llvm_version = llvm_version,
        arch = arch,
        suffix = suffix,
    )

def _windows(llvm_version, arch):
    if arch.endswith("64"):
        win_arch = "win64"
    else:
        win_arch = "win32"

    return "LLVM-{llvm_version}-{win_arch}.exe".format(
        llvm_version = llvm_version,
        win_arch = win_arch,
    )

def _ubuntu_osname(arch, version, major_llvm_version, llvm_version):
    if arch == "powerpc64le":
        if major_llvm_version > 11:
            return "linux-gnu-ubuntu-18.04"
        else:
            return "linux-gnu-ubuntu-16.04"

    is_llvm_major_release = (_minor_llvm_version(llvm_version) == 0) and (_patch_llvm_version(llvm_version) == 0)
    major_ubuntu_version = int(version.split(".")[0])
    if (major_ubuntu_version >= 20 and (not version.startswith("20.04")) and
        (llvm_version in ["11.0.1", "11.1.0"])):
        os_name = "linux-gnu-ubuntu-20.10"
    elif is_llvm_major_release:
        if major_llvm_version >= 14:
            os_name = "linux-gnu-ubuntu-18.04"
        elif major_llvm_version >= 11:
            os_name = "linux-gnu-ubuntu-" + ("20.04" if major_ubuntu_version >= 20 else "16.04")
        elif major_llvm_version >= 8:
            os_name = "linux-gnu-ubuntu-18.04"
        else:
            # Let's default to 16.04 for LLVM releases before LLVM 8.
            os_name = "linux-gnu-ubuntu-16.04"
    else:
        # Availability may be sparse for patch releases.
        if llvm_version in ["16.0.4", "16.0.3", "16.0.2"]:
            os_name = "linux-gnu-ubuntu-22.04"
        elif llvm_version in ["16.0.1"]:
            os_name = "linux-gnu-ubuntu-20.04"
        elif llvm_version in ["15.0.6", "13.0.1"]:
            os_name = "linux-gnu-ubuntu-18.04"
        elif llvm_version in ["15.0.2"]:
            os_name = "unknown-linux-gnu-rhel86"
        elif llvm_version in ["12.0.1", "11.1.0", "11.0.1", "10.0.1", "9.0.1", "8.0.1"]:
            os_name = "linux-gnu-ubuntu-16.04"
        elif llvm_version in ["7.1.0"]:
            os_name = "linux-gnu-ubuntu-14.04"
        else:
            fail("LLVM patch release %s not available for Ubuntu %s" % (llvm_version, version))

    return os_name

def _linux(llvm_version, distname, version, arch):
    major_llvm_version = _major_llvm_version(llvm_version)

    # NOTE: Many of these systems are untested because I do not have access to them.
    # If you find this mapping wrong, please send a Pull Request on Github.
    os_name = None
    if arch in ["aarch64", "armv7a", "mips", "mipsel"]:
        os_name = "linux-gnu"
    elif distname == "freebsd":
        os_name = "unknown-freebsd-%s" % version
    elif distname == "suse":
        os_name = _resolve_version_for_suse(major_llvm_version, llvm_version)
    elif distname in ["ubuntu", "pop"]:
        os_name = _ubuntu_osname(arch, version, major_llvm_version, llvm_version)
    elif ((distname in ["linuxmint"]) and (version.startswith("21") or version.startswith("20") or version.startswith("19"))):
        os_name = _ubuntu_osname(arch, "20.04", major_llvm_version, llvm_version)
    elif distname == "linuxmint" and version.startswith("18"):
        os_name = "linux-gnu-ubuntu-16.04"
    elif distname == "debian":
        int_version = 0
        if version.isdigit():
            int_version = int(version)
        if int_version == 0 or int_version >= 9:
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
    elif distname in ["arch", "manjaro"]:
        os_name = _ubuntu_osname(arch, "20.04", major_llvm_version, llvm_version)
    elif distname == "amzn":
        # Based on the ID_LIKE field, sles seems like the closest available
        # distro for which LLVM releases are widely available.
        os_name = _resolve_version_for_suse(major_llvm_version, llvm_version)
    elif distname == "raspbian":
        arch = "armv7a"
        os_name = "linux-gnueabihf"
    elif distname == "rhel":
        if 8 <= float(version) and float(version) < 9:
            os_name = _ubuntu_osname(arch, "18.04", major_llvm_version, llvm_version)
        elif float(version) >= 9:
            os_name = _ubuntu_osname(arch, "20.04", major_llvm_version, llvm_version)

    if not os_name:
        fail("Unsupported linux distribution and version: %s, %s" % (distname, version))

    return "clang+llvm-{llvm_version}-{arch}-{os_name}.tar.xz".format(
        llvm_version = llvm_version,
        arch = arch,
        os_name = os_name,
    )

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

def llvm_release_name(rctx, llvm_version):
    (os, version, arch) = _os_version_arch(rctx)
    if os == "darwin":
        return _darwin(llvm_version, arch)
    elif os == "windows":
        return _windows(llvm_version, arch)
    else:
        return _linux(llvm_version, os, version, arch)
