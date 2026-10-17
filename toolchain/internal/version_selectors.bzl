# Copyright 2026 The Bazel Authors.
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

"""Shared SemVer requirement clauses and catalogue prerelease admission."""

load("@mboworks_bzl//bzl/versions:versions.bzl", "versions")

_semver = versions.with_mode("semver")

_NEGATED_OPERATORS = ["!=", "!~=", "!~~="]

def _matches(version, requirements):
    """Whether version satisfies every clause, using SemVer release precedence."""
    return _semver.check_all_requirements(
        version,
        requirements,
        constants = {
            "major": _semver.major(version),
            "minor": _semver.minor(version),
            "patch": _semver.patch(version),
        },
    )

def _allows_prerelease(version, requirements):
    """Whether a positive, unprojected clause names this prerelease's release core."""
    if not _semver.is_prerelease(version):
        return True
    if not requirements:
        return False
    core = _semver.components(version)
    return any([
        not getattr(requirement, "component", None) and not getattr(requirement, "expression", None) and
        requirement.op not in _NEGATED_OPERATORS and
        "*" not in requirement.version and
        _semver.is_prerelease(requirement.version) and _semver.eq(_semver.components(requirement.version), core)
        for requirement in requirements
    ])

version_selectors = struct(
    allows_prerelease = _allows_prerelease,
    matches = _matches,
    parse_requirements = _semver.parse_requirements,
)
