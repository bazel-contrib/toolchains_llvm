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
          "<version>": "<url-prefix>"
        }
        // future: description, frozen, source, ...
      },
      "<tarball-basename>": "<sha256>",
      ...
    }

The rule strips `//` line comments and `/* ... */` block comments outside of
strings, decodes the result as JSON, merges every input, and emits a
generated `data.bzl` exporting:

    LLVM_DISTRIBUTIONS           # tarball basename -> sha256
    LLVM_DISTRIBUTIONS_BASE_URL  # version -> URL prefix

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

def _impl(rctx):
    distributions = {}
    base_url = {}
    sources = []
    for src in rctx.attr.srcs:
        data = _load_jsonc(rctx, src)
        for key, value in data.items():
            if key == _META_KEY:
                # Currently only `base_url` is recognized; ignore unknown
                # meta keys so the schema can grow without breaking older
                # versions of this rule.
                for k, v in value.get("base_url", {}).items():
                    base_url[k] = v
                continue

            # Anything else is a distribution entry.
            distributions[key] = value
        sources.append(str(src))

    header = "\n".join([
        "# Auto-generated by //toolchain/internal:distributions_repo.bzl.",
        "# Do not edit by hand. Sources:",
    ] + ["#   - " + s for s in sources]) + "\n\n"

    body = header + _format_dict("LLVM_DISTRIBUTIONS", distributions) + "\n\n" + \
           _format_dict("LLVM_DISTRIBUTIONS_BASE_URL", base_url) + "\n"

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
