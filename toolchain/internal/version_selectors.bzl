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

"""Shared SemVer requirement clauses."""

load("@mboworks_bzl//bzl/versions:versions.bzl", "versions")

_semver = versions.with_mode("semver")

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

def _is_selector(selection):
    return selection in ["first", "latest"] or selection.startswith("first:") or selection.startswith("latest:")

def _select(selection, candidates, *, key = None, allow_prereleases = False):
    """Pick a compatible candidate with the same bzl policy for LLVM and linkers."""
    if not _is_selector(selection):
        fail("ERROR: Invalid version requirements: '{}'".format(selection))
    expression = selection.partition(":")[2]
    requirements = _semver.parse_requirements(expression) if ":" in selection else None
    pick = _semver.latest if selection.startswith("latest") else _semver.earliest
    return pick(
        candidates,
        key = key,
        include_requirements = lambda v: not requirements or _matches(v, requirements),
        exclude_requirements = None if allow_prereleases else _semver.is_prerelease,
    )

def _resolve(version_or_requirements, available_versions, *, allow_prereleases = False):
    """Resolve an exact version or first/latest requirement against versions."""
    if not version_or_requirements:
        fail("ERROR: Empty version selection.")
    if not _is_selector(version_or_requirements):
        if version_or_requirements not in available_versions:
            fail("ERROR: Version '{}' is not available; supported versions: {}".format(
                version_or_requirements,
                ", ".join(_semver.sorted(available_versions)),
            ))
        return version_or_requirements

    selected = _select(version_or_requirements, available_versions, allow_prereleases = allow_prereleases)
    if selected != None:
        return selected
    fail("ERROR: No version matches '{}' in: {}".format(
        version_or_requirements,
        ", ".join(_semver.sorted(available_versions)),
    ))

def _resolve_environment(rctx, selection):
    """Expand an environment-provided exact version or selector for either tool."""
    if selection.startswith("getenv(") and selection.endswith(")"):
        env_var = selection[len("getenv("):-1]
        if env_var.find(",") >= 0:
            env_name, env_default = env_var.split(",", 1)
        else:
            env_name = env_var
            env_default = None

        env_name = env_name.strip(" ")
        if not env_name:
            fail("ERROR: Bad getenv parameter '{env_var}'.".format(
                env_var = env_var,
            ))

        # We prefer 'repository_ctx.getenv' if it is available (~7.1+) and default
        # to accessing the environment directly. The latter breaks "hermeticity".
        if hasattr(rctx, "getenv"):
            selection = rctx.getenv(env_name, env_default)
        elif env_name in rctx.os.environ:
            selection = rctx.os.environ[env_name]
        else:
            selection = env_default

        if not selection:
            fail("ERROR: Empty getenv lookup for '{env_var}'.".format(
                env_var = env_var,
            ))

    return selection

version_selectors = struct(
    matches = _matches,
    resolve = _resolve,
    resolve_environment = _resolve_environment,
    select = _select,
    parse_requirements = _semver.parse_requirements,
)
