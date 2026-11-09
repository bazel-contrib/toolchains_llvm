# Distribution catalogue profiles

`extra_llvm_distribution_files` accepts JSON/JSONC catalogues. Checksum entries
remain `"archive-name": "sha256"`; optional `_meta` fields describe all entries
in that file. Existing catalogues require no changes.

```jsonc
{
  "_meta": {
    "base_url": { "": "https://example.org/releases/{version}/" },
    "platforms": {
      "linux-x86_64": "my-llvm-{version}-linux-x86_64.tar.zst",
    },
    "strip_prefix": "",
    "requirements": {
      "features": ["-asan", "-msan"],
      "stdlib": { "linux-x86_64": ["stdc++", "dynamic-stdc++"] },
    },
  },
  "my-llvm-23.1.2-linux-x86_64.tar.zst": "<sha256>",
}
```

| Header field            | Meaning                                                                                                                                                                                                                                     |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `base_url`              | Existing default (`""`) or per-version URL templates; `{version}` is expanded before appending the filename.                                                                                                                                |
| `platforms`             | Execution OS/architecture keys mapped to exact archive filename templates using `{version}`. No wildcard/prefix matching. Every entry must match at least one template. Explicit mappings take precedence over conventional-name discovery. |
| `version`               | Optional explicit LLVM version for archives whose names do not contain it. Otherwise the first numeric hyphen-separated segment supplies the version, including a following LLVM-style `rcN` segment.                                       |
| `strip_prefix`          | Directory to strip during extraction; `""` means the archive already has `bin/` and `lib/` at its root. Omission preserves conventional prefix inference.                                                                                   |
| `requirements.features` | Signed configuration-level feature names, as in feature overrides: `"msan"` requires it, `"-asan"` excludes it. All must match. Explicitly disabled features take precedence.                                                               |
| `requirements.stdlib`   | Target OS/architecture keys (or `""` fallback) mapped to allowed standard libraries. A missing target entry is unrestricted. `stdc++`/`dynamic-stdc++` also admit their version-suffixed forms.                                             |

Use separate files when package families have different requirements or layouts.
Later files replace earlier checksums; a checksum-only override retains the
earlier URL and metadata. A later nonempty profile replaces the earlier profile.
Inline checksum overrides also retain a matching file's metadata. Custom names
need explicit `platforms` mappings for automatic `first`/`latest` selection.

Metadata is recorded alongside the extracted compiler and follows shared-archive
feature overrides. Requirements are checked against the selected variant's
configuration during toolchain resolution, independently for target and execution
configurations (`--features` and `--host_features`). Inactive variants and
nonmatching target platforms are not rejected. Rule-local `features` do not
select a distribution. Manually supplied toolchain roots without the generated
metadata file retain their existing behavior.

## MSan-specific distributions

The opt-in `@toolchains_llvm//toolchain/distributions:msan.jsonc` catalogue
provides matched LLVM 22.1.8 compiler and MSan-instrumented libc++ packages from
[RealtimeRoboticsGroup/toolchains](https://github.com/RealtimeRoboticsGroup/toolchains/releases/tag/22.1.8).
It supports native Linux x86_64 and AArch64. Both archives are checksum-pinned;
the overlay is selected by the compiler's exact version and execution platform,
then extracted into `libcxx-msan/` automatically. There are no separate runtime
version selectors or caller-provided runtime URLs/checksums to keep in sync.

Select this catalogue through an `llvm.feature_override` with
`features = ["msan"]`, as shown in the README. The profile requires MSan and
`builtin-libc++`; it rejects incompatible sanitizer combinations. Keep an ordinary
compiler as the default for non-MSan targets and execution tools. The catalogue
is curated separately from the official LLVM updater.

For another complete archive intended only for MemorySanitizer builds, declare:

```jsonc
"requirements": { "features": ["msan"] }
```

The requirement validates usage; it does not enable instrumentation. Companion
archives can be declared in the same header:

```jsonc
"overlays": {
  "libcxx-msan": {
    "22.1.8": {
      "linux-x86_64": {
        "url": "https://example.org/{version}/libcxx-msan-{version}.tar.zst",
        "sha256": "<64 hexadecimal characters>",
        "strip_prefix": "", // optional; the archive root is used by default
      },
    },
  },
}
```

The structure is output directory → exact LLVM version → execution platform →
archive descriptor. Output names must be simple directory names, not paths.
URLs may contain `{version}`; every overlay requires a SHA-256. A missing version
or platform is an error, not a fallback to another runtime. Target platforms do
not select these overlays; cross-target runtime packaging is not provided by
this native MSan catalogue. Specifying `libcxx_url` together with a catalogued
`libcxx-msan` overlay is rejected rather than combining two runtime sources.

An optional `libcxx_url` overlay is different: the base compiler remains usable
without MSan, and the existing `msan` feature selects the instrumented libc++.
Do not mark that ordinary base compiler MSan-only merely because an overlay
was configured. Match the compiler and instrumented runtime LLVM versions.

## hermetic-llvm packages

The opt-in `@toolchains_llvm//toolchain/distributions:hermetic_llvm.jsonc`
catalogue provides LLVM 23.1.2 Linux/macOS packages from release `llvm-23.1.2-2`.
It is not merged into the default catalogue and is currently curated separately
from the official LLVM updater.

The packages contain a multicall LLVM executable and Clang resource headers,
not libc++, compiler-rt, sanitizer runtimes, or an Apple LTO plugin. Linux support
uses the host/sysroot's libstdc++ and libgcc; macOS uses Apple SDK libc++ and
`linker = "auto"`. Sanitizers are explicitly excluded by this profile. LTO/plugin
availability is not added or guaranteed by accepting the compiler archive.

Other compiler-only packages may omit auxiliary tools or top-level `include/`.
Required compiler/linker tools and Clang resource headers remain required.
Missing optional tools are not added to ordinary action inputs; features such as
coverage or `.dwp` generation still need the corresponding tools installed.
