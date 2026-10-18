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

"""Golden-output tests for LLVM distribution lookup and version selection."""

load("@llvm_distributions_data//:data.bzl", "LLVM_DISTRIBUTIONS")
load("@mboworks_bzl//bzl/versions:versions.bzl", "versions")
load(":llvm_distributions.bzl", _testing = "testing")

_semver = versions.with_mode("semver")

def _parse_version(version):
    return tuple(_semver.parse(version))

def _distributions_test_writer_impl(ctx):
    """Analyze the configured versions and write to a file for test consumption.

    The test generated file '<rule_name>.out' contains the following lines:
    - a 'del:' line denotes a llvm distribution basename that was not found.
    - a 'add:' line denotes a version that was predicted but does not exist.

    Lines of type `add:` should never occur as the algorithm is supposed to
    verify that predicted distributions have been configured. Otherwise the
    algorithm could not know the hash value.
    """
    use_llvm_distributions = LLVM_DISTRIBUTIONS

    # Inject version '0.0.0' that verifies additional behavior using `extra_llvm_distributions`.
    extra_llvm_distributions = {
        # Keep both formats to verify that automatic selection avoids zstd
        # until Bazel supports the large windows used by LLVM 23 archives.
        "LLVM-0.0.0-Linux-ARM64.tar.zst": "d6b8679be46bdaa383e0c7f13a473ca8f7a4f87233f2cc0e0a7ab19e1b6265e7",
        "LLVM-0.0.0-Linux-ARM64.tar.xz": "a6b8679be46bdaa383e0c7f13a473ca8f7a4f87233f2cc0e0a7ab19e1b6265e7",
        "/foo/bar/LLVM-0.0.0-Linux-X64.tar.xz?xyz": "0a764a8ca521606532ca9ec4e5745c933b16b7d30f4701a47ee851d448fcdb74",
        "http://server/foo/bar/LLVM-0.0.0-macOS-ARM64.tar.xz#xyz": "9da86f64a99f5ce9b679caf54e938736ca269c5e069d0c94ad08b995c5f25c16",
        "http://server/foo/bar/LLVM-0.0.0-macOS-X64.tar.xz": "264f2f1e8b67f066749349ae8b4943d346cd44e099464164ef21b42a57663540",
        "http://server/clang%2Bllvm-0.0.0-aarch64-pc-windows-msvc.tar.xz": "5916d93bf80e3ae504022cdd8cb8887be001f9b68a7a08bd268727e8d858afa4",
        "http://server/path-to-file/clang%2Bllvm-0.0.0-x86_64-pc-windows-msvc.tar.xz#bla": "5916d93bf80e3ae504022cdd8cb8887be001f9b68a7a08bd268727e8d858afa4",
    }

    arch_list = [
        "aarch64",
        "armv7a",
        "mips",
        "mipsel",
        "powerpc64",
        "powerpc64le",
        "sparc64",
        "sparcv9",
        "x86_32",
        "x86_64",
    ]
    arch_alias_dict = {
        "sparc64": ["sparc64", "sparcv9"],
        "sparcv9": ["sparcv9", "sparc64"],
    }
    os_list = [
        "darwin",
        "linux",
        "windows",
    ]
    ANY_VERSION = "0"  # Version does not matter, but must be a valid integer
    dist_dict_list = {
        "linux": [
            # keep sorted
            struct(name = "amzn", version = ANY_VERSION),
            struct(name = "arch", version = ANY_VERSION),
            struct(name = "centos", version = "6"),
            struct(name = "centos", version = "7"),
            struct(name = "chainguard", version = ANY_VERSION),
            struct(name = "debian", version = "0"),
            struct(name = "debian", version = "8"),
            struct(name = "debian", version = "9"),
            struct(name = "fedora", version = "26"),
            struct(name = "fedora", version = "27"),
            struct(name = "fedora", version = "42"),
            struct(name = "freebsd", version = "10"),
            struct(name = "freebsd", version = "11"),
            struct(name = "freebsd", version = "12"),
            struct(name = "freebsd", version = "13"),
            struct(name = "ibm-aix", version = "7.2"),
            struct(name = "linuxmint", version = "18"),
            struct(name = "linuxmint", version = "19"),
            struct(name = "pc-solaris", version = "2.11"),
            struct(name = "raspbian", version = ANY_VERSION),
            struct(name = "rhel", version = ANY_VERSION),
            struct(name = "sun-solaris", version = "2.11"),
            struct(name = "suse", version = "11.3"),
            struct(name = "suse", version = "12.2"),
            struct(name = "suse", version = "12.3"),
            struct(name = "suse", version = "12.4"),
            struct(name = "suse", version = "15.5"),
            struct(name = "suse", version = "16.0"),
            struct(name = "suse", version = "17.0"),
            struct(name = "ubuntu", version = "14.04"),
            struct(name = "ubuntu", version = "16.04"),
            struct(name = "ubuntu", version = "18.04.5"),
            struct(name = "ubuntu", version = "18.04.6"),
            struct(name = "ubuntu", version = "18.04"),
            struct(name = "ubuntu", version = "20.04"),
            struct(name = "ubuntu", version = "20.10"),
            struct(name = "ubuntu", version = "22.04"),
            struct(name = "ubuntu", version = "24.04"),
            struct(name = "void", version = ANY_VERSION),
            struct(name = "wolfi", version = ANY_VERSION),
        ],
    }

    # Define the min real version. For earlier injected versions we do no perform dist testing.
    MIN_VERSION = _parse_version("6.0.0")

    # Additional output will be generated for versions up to and including `MAX_VERSION`
    MAX_VERSION = _parse_version("20.1.3")
    version_dict = {
        _parse_version(_testing.distribution_version_string(basename)): None
        for basename in use_llvm_distributions.keys() + extra_llvm_distributions.keys()
    }
    versions = sorted(version_dict.keys())

    # Write versions to output to check which versions we take into account.
    output = []
    select = []
    for version in versions:
        output.append("version: " + _semver.normalize_string(version))

    # We keep track of versions in `not_found` and remove the ones we found.
    # So at the end all version that were not found remain, hence the name.
    not_found = {
        _testing.distribution_basename(distribution): None
        for distribution in use_llvm_distributions.keys() + extra_llvm_distributions.keys()
    }

    # While computing we add predicted versions that are not configured as True.
    # At the end we add the not-found versions as False.
    result = {}

    # Collect cases that produce duplicates (or multiple) basenames.
    dupes = []

    # For all versions X arch X os check if we can compute the distribution.
    for version in versions:
        all_llvm_distributions = _testing.get_all_llvm_distributions(
            llvm_distributions = use_llvm_distributions,
            extra_llvm_distributions = extra_llvm_distributions,
            parsed_llvm_version = version,
        )
        for basename, distribution in all_llvm_distributions.items():
            _, shaerr = _testing.normalize_and_check_sha256(distribution.sha256)
            if shaerr:
                output.append("err: {basename}: bad sha256: {shaerr}".format(
                    basename = basename,
                    shaerr = shaerr,
                ))
        for arch in arch_list:
            for os in os_list:
                if version < MIN_VERSION:
                    # Limit the injected version checks
                    if arch not in ["aarch64", "x86_64"]:
                        break
                    dist_list = [struct(name = os, version = "")]
                else:
                    dist_list = dist_dict_list.get(os, [struct(name = os, version = "")])
                for dist in dist_list:
                    if arch == "sparc64" and dist.name != "sun-solaris":
                        # Sparc64 and SparcV9 are handled in the same way, just different precedence.
                        # One is the architecture th other the ISA. Restrict to one to limit output.
                        continue
                    host_info = struct(
                        arch = arch,
                        os = os,
                        dist = dist,
                    )
                    basenames = _testing.find_llvm_basename_list(_semver.normalize_string(version), all_llvm_distributions, host_info)
                    if version <= MAX_VERSION:
                        predicted, error = _testing.find_llvm_basename_or_error(
                            _semver.normalize_string(version),
                            all_llvm_distributions,
                            host_info,
                        )
                        skip_output = False
                        if error:
                            if error.startswith("ERROR: No matching config could be found for version"):
                                skip_output = True
                        else:
                            if predicted.endswith(".exe"):
                                error = "ERROR: Windows .exe is not supported: " + predicted
                            elif predicted not in all_llvm_distributions:
                                error = "ERROR: Unavailable prediction: " + predicted
                            elif len(basenames) == 0:
                                skip_output = True
                            elif len(basenames) == 1:
                                predicted = basenames[0]
                            else:
                                error = "ERROR: Multiple selections"
                            if not error:
                                arch_found = [arch for arch in arch_list if arch in predicted]
                                if len(arch_found) == 1 and arch_found[0] not in arch_alias_dict.get(arch, [arch]):
                                    error = "ERROR: Bad arch selection: " + predicted
                        if not skip_output:
                            select.append("{version}-{arch}-{os}/{dist_name}/{dist_version} -> {basename}".format(
                                version = _semver.normalize_string(version),
                                arch = arch,
                                os = os,
                                dist_name = dist.name,
                                dist_version = dist.version,
                                basename = error or predicted,
                            ))
                    if len(basenames) != 1:
                        if basenames:
                            dupes.append("dup: {version}-{arch}-{os}-{dist_name}-{dist_version} -> {count}".format(
                                version = _semver.normalize_string(version),
                                arch = arch,
                                os = os,
                                dist_name = dist.name,
                                dist_version = dist.version,
                                count = len(basenames),
                            ))
                            dupes.extend(["   : " + basename for basename in basenames])
                        continue
                    basename = basenames[0]
                    if basename in all_llvm_distributions:
                        if basename in not_found:
                            not_found.pop(basename)
                    else:
                        result[basename] = True

    # Build result
    for dist in not_found:
        result[dist] = False
    output += [("add: " if found else "del: ") + dist for dist, found in result.items()]
    output += dupes
    ctx.actions.write(ctx.outputs.output, "\n".join(output) + "\n")
    ctx.actions.write(ctx.outputs.select, "\n".join(select) + "\n")

distributions_test_writer = rule(
    implementation = _distributions_test_writer_impl,
    attrs = {
        "output": attr.output(mandatory = True),
        "select": attr.output(mandatory = True),
    },
)

def _requirements_test_writer_impl(ctx):
    """Analyze the configured versions and write to a file for test consumption.
    The test generated file '<rule_name>.out' contains the following lines:
    [<arch>,<os>,<requirement>]: <llvm_distribution_basename>
    """
    all_llvm_distributions = {
        # In order to prevent new distributions to interfere we cut at 20.1.3.
        k: v
        for k, v in LLVM_DISTRIBUTIONS.items()
        if _parse_version(_testing.distribution_version_string(k)) <= (20, 1, 3)
    }
    requirement_list = [
        "latest:<=20.1.0",
        "latest:<=20.1.0,>17.0.4,!=19.1.7",
        "latest:<20.1.0,>17.0.4,!=19.1.7",
        "latest:<20.1.0,>17.0.4",
        "latest:>=15.0.6,<16",
        "first:>=15.0.6,<16",
        "latest",
        "first",
    ]
    arch_list = [
        "aarch64",
        "armv7a",
        "x86_64",
    ]
    os_list = [
        "darwin",
        "linux",
        "windows",
    ]
    ANY_VERSION = "0"  # Version does not matter, but must be a valid integer
    dist_dict_list = {
        "linux": [
            # keep sorted
            struct(name = "ubuntu", version = ANY_VERSION),
            struct(name = "raspbian", version = ANY_VERSION),
            struct(name = "rhel", version = ANY_VERSION),
        ],
    }
    result = []
    for arch in arch_list:
        for os in os_list:
            dist_list = dist_dict_list.get(os, [struct(name = os, version = "")])
            for dist in dist_list:
                for requirement in requirement_list:
                    host_info = struct(
                        arch = arch,
                        os = os,
                        dist = dist,
                    )
                    llvm_version, basename, error = _testing.required_llvm_release_name(
                        version_or_requirements = requirement,
                        all_llvm_distributions = all_llvm_distributions,
                        host_info = host_info,
                    )
                    if llvm_version and basename:
                        result.append("[{arch},{os}{dist_name}{dist_version},'{requirement}']: {llvm_version} = {basename}".format(
                            arch = arch,
                            os = os,
                            dist_name = "," + dist.name if os == "linux" else "",
                            dist_version = "," + dist.version if os == "linux" else "",
                            requirement = requirement,
                            llvm_version = llvm_version,
                            basename = basename,
                        ))
                    else:
                        result.append("[{arch},{os},\"{requirement}\"]: {error}".format(
                            arch = arch,
                            os = os,
                            requirement = requirement,
                            llvm_version = llvm_version,
                            basename = basename,
                            error = error or "ERROR: N/A",
                        ))
    ctx.actions.write(ctx.outputs.result, "\n".join(result) + "\n")

requirements_test_writer = rule(
    implementation = _requirements_test_writer_impl,
    attrs = {
        "result": attr.output(mandatory = True),
    },
)

def _prerelease_test_writer_impl(ctx):
    # Exercise the checked-in release table so this also proves that published
    # prereleases are bundled, not merely supported through user-supplied data.
    distributions = LLVM_DISTRIBUTIONS
    host = struct(
        arch = "x86_64",
        os = "linux",
        dist = struct(name = "ubuntu", version = "24.04"),
    )
    result = []

    for requested in ["23.1.0-rc3", "22.1.8"]:
        available = _testing.get_all_llvm_distributions(
            llvm_distributions = distributions,
            extra_llvm_distributions = {},
            parsed_llvm_version = _parse_version(requested),
        )
        _, basename, error = _testing.required_llvm_release_name(
            version_or_requirements = requested,
            all_llvm_distributions = available,
            host_info = host,
        )
        result.append("exact {version}: {result}".format(
            version = requested,
            result = error or basename,
        ))

    all_distributions = _testing.get_all_llvm_distributions(
        llvm_distributions = distributions,
        extra_llvm_distributions = {},
        parsed_llvm_version = None,
    )
    for allow_prereleases in [False, True]:
        for requested in ["latest", "latest:>=23", "latest:>22", "latest:>=23.1.0-rc1"]:
            version, basename, error = _testing.required_llvm_release_name(
                version_or_requirements = requested,
                all_llvm_distributions = all_distributions,
                host_info = host,
                allow_prereleases = allow_prereleases,
            )
            result.append("allow_prereleases={allow_prereleases} {requested}: {result}".format(
                requested = requested,
                allow_prereleases = allow_prereleases,
                result = error or "{} = {}".format(version, basename),
            ))

    # Fixed synthetic catalogue: latest is host-specific, constrained by the
    # release series, and must not admit an otherwise newer prerelease.
    selector_distributions = _testing.get_all_llvm_distributions(
        llvm_distributions = {},
        extra_llvm_distributions = {
            "LLVM-23.1.2-Linux-X64.tar.xz": "1" * 64,
            "LLVM-23.1.2-macOS-ARM64.tar.xz": "2" * 64,
            "LLVM-23.1.3-Linux-X64.tar.xz": "3" * 64,
            "LLVM-23.2.0-Linux-X64.tar.xz": "4" * 64,
            "LLVM-23.3.0-rc1-Linux-X64.tar.xz": "5" * 64,
            "LLVM-24.1.0-Linux-X64.tar.xz": "6" * 64,
        },
        parsed_llvm_version = None,
    )
    for selector_host in [host, struct(arch = "aarch64", os = "darwin", dist = struct(name = "darwin", version = ""))]:
        for allow_prereleases in [False, True]:
            for requested in [
                "latest:major==23",
                "latest:major()==23",
                "latest:major==23,minor==1",
                "first:major==23",
                "latest:~=23.1.0",
                "latest:~~=23.1.*",
                "latest:!~=23.2.0,!~~=24.*",
                "latest:==23.1.*",
            ]:
                version, basename, error = _testing.required_llvm_release_name(
                    version_or_requirements = requested,
                    all_llvm_distributions = selector_distributions,
                    host_info = selector_host,
                    allow_prereleases = allow_prereleases,
                )
                result.append("synthetic {} allow_prereleases={} {}: {}".format(
                    selector_host.os,
                    allow_prereleases,
                    requested,
                    error or "{} = {}".format(version, basename),
                ))

    # With built-ins suppressed, version resolution must see only the user
    # entries. In particular, `latest` must not leak a newer bundled release.
    custom_only = _testing.get_all_llvm_distributions(
        llvm_distributions = {},
        extra_llvm_distributions = {
            "https://example.com/LLVM-20.1.4-Linux-X64.tar.xz": "3" * 64,
        },
        parsed_llvm_version = None,
    )
    version, basename, error = _testing.required_llvm_release_name(
        version_or_requirements = "latest",
        all_llvm_distributions = custom_only,
        host_info = host,
    )
    result.append("custom-only latest: {result}".format(
        result = error or "{} = {}".format(version, basename),
    ))
    builtin_basename = "LLVM-22.1.8-Linux-X64.tar.xz"
    result.append("custom-only bundled URL: {}".format(
        _testing.configured_distribution_url(
            basename = builtin_basename,
            use_builtin_llvm_distributions = False,
            user_distribution_urls = {},
        ) or "suppressed",
    ))
    ctx.actions.write(ctx.outputs.result, "\n".join(result) + "\n")

prerelease_test_writer = rule(
    implementation = _prerelease_test_writer_impl,
    attrs = {
        "result": attr.output(mandatory = True),
    },
)
