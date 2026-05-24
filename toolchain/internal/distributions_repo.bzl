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

"""Repository rule that merges the JSONC distribution data files into a
generated `data.bzl` consumed by `//toolchain/internal:llvm_distributions.bzl`.

Each input is a JSONC file with a flat object whose keys are either:

  * the reserved `_meta` key, holding configuration that is not itself a
    distribution entry (currently just `base_url`; more may be added later);
  * a tarball basename mapping to its SHA-256.

Schema:

    {
      // free-form header comments are stripped before parsing
      "_meta": {
        "base_url": {
          // "" is the per-file default, applied to every version whose
          // distributions appear in this file. URLs may contain the
          // `{version}` placeholder, which is substituted at materialization
          // time, and should end with `/` -- the basename is appended
          // directly.
          "": "<url-template>",
          // Explicit per-version override (rare).
          "<version>": "<url-template>"
        }
        // future: description, frozen, source, ...
      },
      "<tarball-basename>": "<sha256>",
      ...
    }

The rule strips `//` line comments and `/* ... */` block comments outside of
strings, decodes the result as JSON, merges every input, and emits a
generated `data.bzl` exporting:

    LLVM_DISTRIBUTIONS      # tarball basename -> sha256
    LLVM_DISTRIBUTION_URLS  # tarball basename -> full download URL

URLs are fully expanded at load time: the `""` per-file default and any
explicit per-version override are substituted with `{version}` and joined
with the basename, so the runtime only does a basename->URL dict lookup. The
`""` key is scoped to the versions whose distributions appear in that file,
so pre_github's `releases.llvm.org` default does not bleed into 19.x+
versions in github.jsonc.

Inputs are merged in the order they appear in `srcs`; later entries overwrite
earlier ones on key collisions. The standard ordering is `pre_github.jsonc`,
`github_legacy.jsonc`, `github.jsonc`, `extra.jsonc`, so downstream patches
to `extra.jsonc` can replace SHA-256 values from any other file (useful for
pinning a custom build of an existing tarball name).
"""

_META_KEY = "_meta"

def _strip_jsonc(text):
    """Strip `//` line comments and `/* ... */` block comments outside strings.

    A small character-by-character scanner -- Starlark has no regex, but the
    state machine is short and the inputs are tiny (a few hundred KB at most).
    """
    out = []
    in_string = False
    escape = False
    i = 0
    n = len(text)
    for _ in range(n + 1):
        if i >= n:
            break
        c = text[i]
        if in_string:
            out.append(c)
            if escape:
                escape = False
            elif c == "\\":
                escape = True
            elif c == "\"":
                in_string = False
            i += 1
            continue
        if c == "\"":
            in_string = True
            out.append(c)
            i += 1
            continue
        if c == "/" and i + 1 < n:
            nxt = text[i + 1]
            if nxt == "/":
                # Skip to end of line (keep the newline so line counts stay sane).
                j = text.find("\n", i)
                i = j if j >= 0 else n
                continue
            if nxt == "*":
                j = text.find("*/", i + 2)
                i = (j + 2) if j >= 0 else n
                continue
        out.append(c)
        i += 1
    return "".join(out)

def _strip_trailing_commas(text):
    """Remove commas that immediately precede a `}` or `]` (with optional
    whitespace between). Starlark's `json.decode` is strict JSON, but JSONC
    and buildifier-formatted JSON both leave trailing commas in place.
    """
    out = []
    in_string = False
    escape = False
    i = 0
    n = len(text)
    for _ in range(n + 1):
        if i >= n:
            break
        c = text[i]
        if in_string:
            out.append(c)
            if escape:
                escape = False
            elif c == "\\":
                escape = True
            elif c == "\"":
                in_string = False
            i += 1
            continue
        if c == "\"":
            in_string = True
            out.append(c)
            i += 1
            continue
        if c == ",":
            j = i + 1
            for _ in range(n - i):
                if j >= n or text[j] not in " \t\n\r":
                    break
                j += 1
            if j < n and (text[j] == "}" or text[j] == "]"):
                # Drop the comma; keep walking from after it.
                i += 1
                continue
        out.append(c)
        i += 1
    return "".join(out)

def _load_jsonc(rctx, label):
    path = rctx.path(label)
    raw = rctx.read(path)
    return json.decode(_strip_trailing_commas(_strip_jsonc(raw)))

def _format_dict(name, mapping):
    if not mapping:
        return "{name} = {{}}".format(name = name)
    lines = ["{name} = {{".format(name = name)]
    for key in sorted(mapping.keys()):
        lines.append("    {key}: {value},".format(
            key = repr(key),
            value = repr(mapping[key]),
        ))
    lines.append("}")
    return "\n".join(lines)

def _basename_version(basename):
    # `basename` is `LLVM-<version>-...` or `clang+llvm-<version>-...`.
    # Mirrors `_distribution_version_string` in `llvm_distributions.bzl`,
    # duplicated here to avoid a dependency cycle (this is a repository rule
    # that runs at fetch time, before the runtime module loads).
    return basename.split("-", 2)[1]

def _impl(rctx):
    distributions = {}
    distribution_urls = {}
    sources = []
    for src in rctx.attr.srcs:
        data = _load_jsonc(rctx, src)

        # Pull `_meta.base_url` (the `""` default + per-version overrides).
        # Currently only `base_url` is recognized inside `_meta`; ignore
        # unknown keys so the schema can grow without breaking older versions
        # of this rule.
        file_default = None
        file_overrides = {}
        meta = data.get(_META_KEY, {})
        for k, v in meta.get("base_url", {}).items():
            if k == "":
                file_default = v
            else:
                file_overrides[k] = v

        # Process each distribution, computing a full per-basename URL from
        # the applicable template (version-specific override > file default).
        # Distributions without a covering template get no URL entry; if a
        # later file (typically extra.jsonc) overrides this basename's
        # sha256 but not its URL, the URL from the earlier file persists.
        for key, value in data.items():
            if key == _META_KEY:
                continue
            distributions[key] = value
            version = _basename_version(key)
            template = file_overrides.get(version, file_default)
            if template != None:
                if "{version}" not in template:
                    fail(
                        "base_url template in %s is missing the {version} placeholder: %s" %
                        (str(src), template),
                    )
                distribution_urls[key] = template.format(version = version) + key.replace("+", "%2B")

        sources.append(str(src))

    header = "\n".join([
        "# Auto-generated by //toolchain/internal:distributions_repo.bzl.",
        "# Do not edit by hand. Sources:",
    ] + ["#   - " + s for s in sources]) + "\n\n"

    body = header + _format_dict("LLVM_DISTRIBUTIONS", distributions) + "\n\n" + \
           _format_dict("LLVM_DISTRIBUTION_URLS", distribution_urls) + "\n"

    rctx.file("data.bzl", body)
    rctx.file("BUILD.bazel", "exports_files([\"data.bzl\"])\n")

llvm_distributions_repo = repository_rule(
    implementation = _impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".jsonc"],
            mandatory = True,
            doc = "JSONC distribution data files to merge.",
        ),
    },
    doc = "Merges JSONC distribution data files into a generated data.bzl.",
)
