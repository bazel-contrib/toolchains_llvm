#!/usr/bin/env python3
"""Refresh checksum-pinned LLVM and linker distribution catalogues."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import urllib.request

MIN_LLVM_MAJOR = 19
LLVM_RELEASES_URL = "https://api.github.com/repos/llvm/llvm-project/releases"
MOLD_RELEASES_URL = "https://api.github.com/repos/rui314/mold/releases"
MOLD_BCR_URL = "https://raw.githubusercontent.com/bazelbuild/bazel-central-registry/main/modules/mold/metadata.json"
LLVM_URL_TEMPLATE = "https://github.com/llvm/llvm-project/releases/download/llvmorg-{version}/"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def version_key(version):
    match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)(?:-rc(\d+))?", version)
    if not match:
        raise ValueError("unsupported version: " + version)
    major, minor, patch, rc = match.groups()
    return int(major), int(minor), int(patch), int(rc is None), int(rc or 0)


def strip_jsonc(text):
    out, in_string, escaped, i = [], False, False, 0
    while i < len(text):
        char = text[i]
        if in_string:
            out.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            i += 1
        elif char == '"':
            in_string = True
            out.append(char)
            i += 1
        elif text.startswith("//", i):
            newline = text.find("\n", i)
            i = len(text) if newline < 0 else newline
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            i = len(text) if end < 0 else end + 2
        else:
            out.append(char)
            i += 1
    return re.sub(r",(?=\s*[}\]])", "", "".join(out))


def load_jsonc(path):
    return json.loads(strip_jsonc(path.read_text()))


def github_token():
    if os.environ.get("GITHUB_TOKEN"):
        return os.environ["GITHUB_TOKEN"]
    if shutil.which("gh"):
        result = subprocess.run(["gh", "auth", "token"], capture_output=True, text=True)
        if result.returncode == 0 and result.stdout.strip():
            print("Using GitHub token from gh CLI.", file=sys.stderr)
            return result.stdout.strip()
    return None


def fetch_json(url, token):
    headers = {"Accept": "application/vnd.github+json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers)) as response:
        return json.load(response)


def fetch_releases(url, token):
    result, page = [], 1
    while True:
        separator = "&" if "?" in url else "?"
        batch = fetch_json(f"{url}{separator}per_page=100&page={page}", token)
        if not isinstance(batch, list):
            raise RuntimeError("expected release list from " + url)
        result.extend(batch)
        if len(batch) < 100:
            return result
        page += 1


def collect_llvm_entries(releases, existing):
    tag_re = re.compile(r"^llvmorg-(\d+\.\d+\.\d+(?:-rc\d+)?)$")
    asset_re = re.compile(r"^(?:clang\+llvm|LLVM)-.*\.tar\.(?:zst|xz|gz)$")
    entries, missing = [], []
    for release in releases:
        match = tag_re.fullmatch(release.get("tag_name", ""))
        if release.get("draft") or not match:
            continue
        version = match.group(1)
        if int(version.split(".")[0]) < MIN_LLVM_MAJOR:
            continue
        names = {asset["name"] for asset in release.get("assets", [])}
        for asset in release.get("assets", []):
            name = asset["name"]
            if not asset_re.fullmatch(name) or f"-{version}-" not in name:
                continue
            if name.endswith(".tar.xz") and name[:-7] + ".tar.zst" in names:
                continue
            digest = (asset.get("digest") or "").removeprefix("sha256:") or existing.get(name, "")
            if not digest:
                if release.get("prerelease"):
                    continue
                missing.append(name)
            else:
                entries.append((version, name, digest))
    if missing:
        raise RuntimeError("LLVM assets lack digests:\n  " + "\n  ".join(sorted(missing)))
    # Stable sorts keep assets alphabetical inside descending version groups.
    entries.sort(key=lambda item: item[1])
    entries.sort(key=lambda item: version_key(item[0]), reverse=True)
    return entries


LLVM_HEADER = '''// Copyright 2018 The Bazel Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Generated by `utils/update_distributions.py`. Do not edit by hand.

'''


def render_llvm_jsonc(entries, overrides):
    versions = {item[0] for item in entries}
    base_urls = {"": LLVM_URL_TEMPLATE}
    base_urls.update({key: value for key, value in overrides.items() if key and key in versions})
    metadata = {
        "description": "GitHub-hosted LLVM distributions (version 19.x and newer).",
        "base_url": base_urls,
    }
    lines = [LLVM_HEADER.rstrip(), "", "{", '  "_meta": ' + json.dumps(metadata, indent=2).replace("\n", "\n  ") + ","]
    previous_version = None
    for version, name, digest in entries:
        if version != previous_version:
            lines.extend(["", "  // " + version])
            previous_version = version
        lines.append("  {}: {},".format(json.dumps(name), json.dumps(digest)))
    lines.append("}")
    return "\n".join(lines) + "\n"


def selected_mold_versions(releases, bcr_version):
    stable = []
    for release in releases:
        match = re.fullmatch(r"v(\d+\.\d+\.\d+)", release.get("tag_name", ""))
        if match and not release.get("draft") and not release.get("prerelease"):
            stable.append(match.group(1))
    stable.sort(key=version_key, reverse=True)
    selected = stable[:3]
    if bcr_version not in selected:
        selected.append(bcr_version)
    return selected


def collect_mold_catalogue(releases, versions):
    by_version = {}
    for release in releases:
        match = re.fullmatch(r"v(\d+\.\d+\.\d+)", release.get("tag_name", ""))
        if match:
            by_version[match.group(1)] = release
    catalogue = {"mold": {}}
    for version in versions:
        if version not in by_version:
            raise RuntimeError(f"mold {version} has no GitHub release")
        platforms = {}
        pattern = re.compile(rf"^mold-{re.escape(version)}-(aarch64|x86_64)-linux\.tar\.gz$")
        for asset in by_version[version].get("assets", []):
            match = pattern.fullmatch(asset["name"])
            if not match:
                continue
            digest = (asset.get("digest") or "").removeprefix("sha256:")
            if not SHA256_RE.fullmatch(digest):
                raise RuntimeError(asset["name"] + " lacks a GitHub SHA-256 digest")
            platforms["linux-" + match.group(1)] = {
                "urls": [asset["browser_download_url"]], "sha256": digest,
                "strip_prefix": asset["name"].removesuffix(".tar.gz"), "binary": "bin/mold",
            }
        if set(platforms) != {"linux-aarch64", "linux-x86_64"}:
            raise RuntimeError(f"mold {version} lacks required Linux assets")
        catalogue["mold"][version] = platforms
    return catalogue


LINKER_HEADER = '''// Copyright 2026 The Bazel Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Generated by `utils/update_distributions.py`. Contains the BCR mold version
// and the three newest stable releases, selected by execution platform.

'''


def render_linkers_jsonc(catalogue):
    return LINKER_HEADER + json.dumps(catalogue, indent=2) + "\n"


def format_files(root, paths):
    relative = [str(path.relative_to(root)) for path in paths]
    if shutil.which("trunk"):
        subprocess.run(["trunk", "fmt", *relative], cwd=root, check=True)
    elif (root / ".trunk/tools/prettier").exists():
        subprocess.run([str(root / ".trunk/tools/prettier"), "--write", *relative], cwd=root, check=True)


def update_goldens(root):
    subprocess.run(["bazel", "build", "//toolchain/internal:llvm_distributions", "//toolchain/internal:llvm_prerelease_test_output"], cwd=root, check=True)
    bazel_bin = Path(subprocess.check_output(["bazel", "info", "bazel-bin"], cwd=root, text=True).strip())
    shutil.copyfile(bazel_bin / "toolchain/internal/llvm_distributions.out.txt", root / "toolchain/internal/llvm_distributions.golden.out.txt")
    shutil.copyfile(bazel_bin / "toolchain/internal/llvm_prerelease_test.output.txt", root / "toolchain/internal/llvm_prerelease_test.golden.txt")


def main():
    argparse.ArgumentParser(description=__doc__).parse_args()
    root = Path(__file__).resolve().parent.parent
    llvm_path = root / "toolchain/distributions/github.jsonc"
    linker_path = root / "toolchain/distributions/linkers.jsonc"
    token = github_token()
    existing = load_jsonc(llvm_path)
    entries = collect_llvm_entries(fetch_releases(LLVM_RELEASES_URL, token), {key: value for key, value in existing.items() if key != "_meta"})
    llvm_path.write_text(render_llvm_jsonc(entries, existing.get("_meta", {}).get("base_url", {})))
    mold_releases = fetch_releases(MOLD_RELEASES_URL, token)
    bcr_version = fetch_json(MOLD_BCR_URL, token)["versions"][-1]
    versions = selected_mold_versions(mold_releases, bcr_version)
    linker_path.write_text(render_linkers_jsonc(collect_mold_catalogue(mold_releases, versions)))
    print("Selected mold versions: " + ", ".join(versions), file=sys.stderr)
    format_files(root, [llvm_path, linker_path])
    update_goldens(root)


if __name__ == "__main__":
    main()
