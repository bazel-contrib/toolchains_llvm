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

"""Version-selector regression tests independent of the mutable LLVM catalogue."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts", "unittest")
load(":linker_distributions.bzl", "resolve_linker_distribution")
load(":llvm_distributions.bzl", "resolve_version")
load(":version_selectors.bzl", "allows_prerelease", "matches", "parse_requirements")

def _requirements_test_impl(ctx):
    env = unittest.begin(ctx)
    for candidate, expression, expected in [
        ("23.1.2", "major()==23", True),
        ("23.1.0-rc1", 'prerelease()=="rc1"', True),
        ("23.1.0-rc1", 'prerelease ()=="rc,1"', False),
        ("23.1.0-rc1", 'prerelease()=="rc.1"', False),
        ("23.1.0-rc1", "is_prerelease()==True", True),
        ("23.1.0-rc1", 'has_prerelease_prefix("rc")==True', True),
        ("23.1.2", "component_count()==3,component(-1)==2", True),
        ("23.1.2", "major==23", True),
        ("24.1.0", "major==23", False),
        ("23.2.1", "major==23,minor>=2,patch==1", True),
        ("23.1.2", "major==23,minor>=2", False),
        ("23", "minor==0,patch==0", True),
        ("23.1.2", "major==23,major()==23,prefix(minor)==23", True),
        ("23.1.2", "prefix(2)==23.1", True),
        ("23.1.2", "components(start=1,end=3)==1.2", True),
        ("23.1.2", "major(prefix(2))==23", True),
        ("23.1.2", 'prefix("24.3.2",2)==24.3', True),
        ("24.1.0", "major()==23", False),
        ("23.2.0", "major()==23,minor()==1", False),
        ("23.1.9", "major()==23,minor()==1", True),
        ("23.1.2.7", "major()==23,minor()==1,patch()==2", True),
        ("23.1.3", "major()==23,minor()==1,patch()==2", False),
        ("23", "minor()==0", True),
        ("23.1", "patch()==0", True),
        ("23.2.0", "major()==23,minor()>=1,minor()<3", True),
        ("23.1.2", "major()>=23,patch()!=1", True),
        ("23.2.1", "major()==23,minor()>=2", True),
        ("23.1.9", "major()==23,minor()>=2", False),
        ("23.1.2", "~=23.1", True),
        ("23.2.0", "~=23.1.0", False),
        ("23.2.0", "!~=23.1.0", True),
        ("23.1.2", "~~=23.1.*", True),
        ("23.2.0", "!~~=23.1.*", True),
        ("23.1.2", "==23.1.*", True),
        ("23.1.2", "!=23.1.2", False),
        ("23.1.2", "==23.1", False),
        ("23.1.0", "==23.1", True),
        ("23.1.0-rc.1", "~~=23.1.*", False),
        ("23.1.0-rc.1", "==23.1.*", True),
        ("23.1.0-rc10", "<23.1.0-rc2", True),
        ("23.1.2+build", " major() == 23 , minor() == 1 ", True),
    ]:
        asserts.equals(env, expected, matches(candidate, parse_requirements(expression)), "{} {}".format(candidate, expression))
    return unittest.end(env)

def _resolution_test_impl(ctx):
    env = unittest.begin(ctx)
    available = ["24.1.0", "23.1.0-rc2", "23.1.3", "22.1.8", "23.1.2", "23.1.0-rc10", "25.1.0-rc1"]
    for selection, expected in [
        ("latest:major()==23", "23.1.3"),
        ("latest:major==23", "23.1.3"),
        ("latest:major==23,is_prerelease()==False", "23.1.3"),
        ("first:major==23", "23.1.2"),
        ("latest:major==23,minor==1,patch!=3", "23.1.2"),
        ("latest:prefix(2)==23.1", "23.1.3"),
        ("latest:major()==23,components(start=1,end=2)==1", "23.1.3"),
        ("first:major()==23", "23.1.2"),
        ("latest:major()==23,minor()==1,patch()!=3", "23.1.2"),
        ("latest:~=23.1.0,!=23.1.3", "23.1.2"),
        ("latest:!~=23.1.0", "24.1.0"),
        ("latest:~~=23.1.*,!=23.1.3", "23.1.2"),
        ("latest:!~~=23.1.*", "24.1.0"),
        ("latest:==23.1.*", "23.1.3"),
        ("latest", "24.1.0"),
        ("first", "22.1.8"),
        ("first:>=23.1.0-rc10,<23.1.0", "23.1.0-rc10"),
        ("latest:>=23.1.0-rc10,<23.1.0", "23.1.0-rc2"),
        ('latest:>=23.1.0-rc10,<23.1.0,has_prerelease_prefix("rc")==True', "23.1.0-rc2"),
        ('latest:>=23.1.0-rc10,<23.1.0,prerelease()=="rc10"', "23.1.0-rc10"),
        ("23.1.0-rc2", "23.1.0-rc2"),
    ]:
        asserts.equals(env, expected, resolve_version(selection, available), selection)
    catalogue = {"test": {
        "23.1.2": {"linux-x86_64": {"binary": "linux-old"}, "darwin-aarch64": {"binary": "darwin"}},
        "23.1.3": {"linux-x86_64": {"binary": "linux-new"}},
        "24.1.0": {"linux-x86_64": {"binary": "next-major"}},
    }}
    for platform, expected in [("linux-x86_64", "23.1.3"), ("darwin-aarch64", "23.1.2")]:
        selected, _distribution = resolve_linker_distribution(catalogue, "test", "latest:major==23", platform)
        asserts.equals(env, expected, selected)
    return unittest.end(env)

def _prerelease_test_impl(ctx):
    env = unittest.begin(ctx)
    for candidate, expression, expected in [
        ("23.1.0-rc2", ">=23", False),
        ("23.1.0-rc2", "major()==23", False),
        ("23.1.0-rc2", "major==23", False),
        ("23.1.0-rc2", 'components("23.1.0-rc1")==23.1.0-rc1', False),
        ("23.1.0-rc2", "prefix(3)>=23.1.0-rc1", False),
        ("23.1.0-rc2", "==23.1.*", False),
        ("23.1.0-rc2", ">=23.1.0-rc1", True),
        ("23.1.0-rc.2", ">=23.1-rc.1", True),
        ("23.1.1-rc2", ">=23.1.0-rc1", False),
        ("23.1.0-rc2", "!=23.1.0-rc1", False),
        ("23.1.0-rc2", ">=23.1.0-rc1,!=23.1.0-rc1", True),
        ("23.1.0-rc2", "!~=23.1.0-rc1", False),
        ("23.1.0-rc2", "!~~=22.*", False),
        ("23.1.0", "major()==23", True),
        ("23.1.0+-.rc1", "major()==23", True),
    ]:
        asserts.equals(env, expected, allows_prerelease(candidate, parse_requirements(expression)), "{} {}".format(candidate, expression))
    asserts.false(env, allows_prerelease("23.1.0-rc2", None))
    return unittest.end(env)

def _invalid_impl(ctx):
    if ctx.attr.selection:
        resolve_version(ctx.attr.selection, ["23.1.2", "24.1.0"])
    else:
        parse_requirements(ctx.attr.expression)
    return []

_invalid = rule(
    implementation = _invalid_impl,
    attrs = {"expression": attr.string(), "selection": attr.string()},
)

def _invalid_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, ctx.attr.message)
    return analysistest.end(env)

_invalid_test = analysistest.make(_invalid_test_impl, expect_failure = True, attrs = {"message": attr.string()})
_requirements_test = unittest.make(_requirements_test_impl)
_resolution_test = unittest.make(_resolution_test_impl)
_prerelease_test = unittest.make(_prerelease_test_impl)

def version_selectors_test_suite(name):
    """Instantiate selector, platform filtering, and invalid-input tests."""
    unittest.suite(name, _requirements_test, _resolution_test, _prerelease_test)
    for suffix, expression, selection, message in [
        ("empty", "", "", "Empty version requirement"),
        ("unknown_constant", "", "latest:mjor==23", "Unknown version constant"),
        ("empty_clause", ">=23,,<24", "", "Empty version requirement"),
        ("projection_operator", "major()=23", "", "non-negative numeric release components"),
        ("major_width", "major()==23.1", "", "non-negative integer operand"),
        ("minor_width", "minor()==23.1.2", "", "non-negative integer operand"),
        ("projection_suffix", "patch()>=23.1.0-rc1", "", "non-negative integer operand"),
        ("bad_wildcard", "==23.*.1", "", "single trailing"),
        ("bool_operand", "", "latest:is_prerelease()==1", "bool operand"),
        ("text_operand", "", "latest:prerelease()==rc1", "arguments must be"),
        ("local_mode", "", 'latest:local()==""', "requires PEP 440 mode"),
        ("no_match", "", "latest:major()==25", "No version matches"),
        ("unavailable", "", "25.1.0", "not available"),
        ("empty_selection", "", "latest:", "Empty version requirement"),
    ]:
        target = name + "_" + suffix
        _invalid(name = target, expression = expression, selection = selection, tags = ["manual"])
        _invalid_test(name = target + "_test", target_under_test = ":" + target, message = message)
