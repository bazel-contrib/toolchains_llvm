# Changelog

Versions below refer to **toolchains_llvm**, not LLVM or Bazel. Historical
entries record notable user-facing feature introductions, checked against
the first release tag containing their implementation. They are not an
exhaustive list of fixes, dependency updates, or newly catalogued LLVM archives.
See the [GitHub releases](https://github.com/bazel-contrib/toolchains_llvm/releases)
for release artifacts and the [README](README.md) for configuration and requirements.

## 1.13.0

### Migration required for prerelease selectors

- Previously, `first` / `latest` selectors admitted prereleases only when a
  requirement explicitly specified a prerelease version, and only for that
  same major/minor/patch release. Starting with 1.13.0, explicitly specifying
  an RC in a requirement is no longer sufficient: also set
  `llvm_version_allow_prereleases = True` for LLVM, or
  `linker_version_allow_prereleases = True` for catalogued linkers. Both options
  default to `False` and are independent. Exact pins, including RC pins, are
  unchanged.
- Prerelease eligibility and version constraints are now separate: enable
  prereleases with the corresponding flag, then use ordinary constraints
  without naming a particular RC. For example,
  `llvm_version = "latest:>23.0,<23.1"` together with
  `llvm_version_allow_prereleases = True` admits LLVM 23.1.0 RCs but excludes
  the final 23.1.0 release. The flag admits all prereleases within the range,
  rather than only those with a release tuple explicitly named in it.
- Version comparisons now use bzl's SemVer mode. Under
  [SemVer's prerelease ordering rules](https://semver.org/#spec-item-11),
  dot-separated numeric identifiers compare numerically (`rc.2 < rc.10`),
  but identifiers containing letters compare lexically (`rc10 < rc2`).
  LLVM currently uses undotted RC identifiers, such as `23.1.0-rc3`.
  A hypothetical `23.1.0-rc10` would therefore sort before `23.1.0-rc2`;
  mixing forms also gives `23.1.0-rc.10 < 23.1.0-rc9`. Use an exact pin
  if that differs from the intended upstream RC order.

### Version selection

- Shared expression-based LLVM and linker version selectors, including
  `major`, `minor`, and `patch` constants, function expressions, wildcards,
  and compatible-release comparisons. Candidates must have an artifact for
  the execution platform before version selection.
- Environment-derived linker versions through `getenv(NAME,fallback)`, matching
  LLVM version selection.
- Independent prerelease policies in feature overrides; linker-only policy
  changes can reuse the base LLVM archive.

### Dependencies and publishing

- WORKSPACE dependencies: `rules_cc` 0.2.27, `apple_support` 2.11.0, and
  `bazel_features` 1.54.1.
- Test dependencies, including `rules_python` 2.4.6, `rules_go` 0.65.0,
  `rules_foreign_cc` 0.17.0, `rules_rust` 0.75.0, and BoringSSL 0.20261020.0.
- BCR publishing workflow to `publish-to-bcr` 1.6.0.

## 1.12.0

- Add checksum-pinned LLVM 23.1.4 archives for Linux ARM64/x86_64, macOS ARM64,
  and Windows ARM64/x86_64. Both xz and zstd metadata are retained; automatic
  selection continues to use xz. Existing LLVM and mold entries are preserved.
- Fix remote execution of dynamically linked LLVM tools: wrappers execute
  auxiliary tools from their original distribution paths, preserving relative
  shared-library lookup. Downloaded distributions supply the relevant LLVM,
  Clang, and libc++ shared libraries as tool inputs.
- Explicit `archive_flags`, `link_libs`, optimization/debug/fastbuild flags,
  coverage flags, and `unfiltered_compile_flags` replace their corresponding
  defaults. Use the corresponding `extra_*` attribute where available for
  additive behavior. `compile_flags`, `cxx_flags`, and `link_flags` still append
  to their computed defaults.
- Use `-fstack-protector-strong` instead of `-fstack-protector` by default.
- Report Linux `target_libc` as `glibc` instead of `glibc_unknown`.
- Upgrade `mboworks_bzl` to 0.8.0 and the WORKSPACE test dependency Google
  Benchmark to 1.10.0. The new selector expressions and explicit prerelease
  controls are introduced in 1.13.0, not in this dependency upgrade.

## 1.11.3

- Recognize LLVM 23.1.3's bundled macOS linker fix. The SDK/TAPI warning now
  applies only to LLVM 23.1.0 through 23.1.2, not all LLVM 23 releases.
- Update WORKSPACE dependencies to `apple_support` 2.10.1 and `bazel_features`
  1.52.0, and test dependencies to `rules_python` 2.4.2 and `rules_go` 0.64.2.

## 1.11.2

- Honor the empty-key fallback in `conly_flags` for every target, matching the
  other flag attributes. These flags apply to C compilation only, not C++.
- Preserve existing linker catalogue versions and execution platforms during
  distribution updates, including mold 2.41.0. The BCR version and three newest
  stable mold releases determine which entries to refresh, not which to retain;
  removing an existing entry requires an explicit change.
- Add checksum-pinned LLVM 23.1.3 archives. Both xz and zstd metadata are retained;
  unsupported zstd archives remain excluded from selection.
- Add mold 3.0.0 for Linux ARM64 and x86_64. Unconstrained mold `latest` now
  selects 3.0.0; previously catalogued versions remain available for exact pins.
- Update `rules_cc` to 0.2.26 in WORKSPACE and test configurations, and
  `rules_python` to 2.4.1 in the test configurations.

## 1.11.1

- Select the matching LLVM `libLTO.dylib` by absolute path when linking on
  macOS. Apple's linker in Command Line Tools 26.2 otherwise ignores Clang's
  relative plugin path and uses its older library, failing to read newer LLVM
  ThinLTO bitcode. Native links retain explicit user-provided LTO libraries;
  compile-only actions, LLD, and non-Darwin targets are unchanged.

## 1.11.0

### Added

- Generic, checksum-pinned downloadable linkers selected by name through
  `linker`, with `linker_version` / `linker_versions` supporting exact versions
  and `first` / `latest` requirements. The built-in catalogue initially contains
  mold; other linker names can be supplied through inline or JSONC catalogues.
- Linker catalogue controls, including custom entries, disabling the built-in
  catalogue, and the `linker_features` capability list.
- Optional mold version inference from an explicitly injected mold Bazel
  module. Depending on that module is not required to use a catalogued mold
  release with an explicit version or requirement.
- Feature-based toolchain overrides with signed predicates such as
  `features = ["thin_lto", "-msan"]`, optional target filters, default fallback,
  ambiguity checks, and configurable merge/reset behavior. Matching uses
  configuration-level `--features` / `--host_features`, not rule-local features.
- Linker-managed macOS ThinLTO through configuration-level `--features=thin_lto`,
  including independent `--host_features` handling for build tools. Linux's
  existing distributed ThinLTO path is unchanged.
- Python-based distribution updater that refreshes both the LLVM catalogue and
  the mold catalogue, retaining the BCR mold version and the three newest stable
  releases. `utils/update_distributions.sh` remains the shell entry point.

### Fixed

- Retain xz, zstd, and gzip archive metadata, but automatically select only xz
  or gzip until Bazel can extract LLVM's large-window zstd archives. Both
  distribution helper scripts now retain all formats instead of dropping xz
  when an equivalent zstd asset exists.
- Warn when LLVM 23 on macOS uses its bundled linker with the known SDK/TAPI
  incompatibility, suggesting the native `auto` linker override.
- Include `libLTO.dylib` in Apple linker sandbox inputs and omit redundant `-lm`
  on macOS.
- Apply MSan instrumentation to C compilation as well as C++, and fail loudly
  when MSan is requested on an unsupported target, including macOS.
- Correct the README's archive-selection policy and distribution updater
  dependencies; exercise both distribution scripts in Linux/macOS CI.

## [1.10.0](https://github.com/bazel-contrib/toolchains_llvm/tree/v1.10.0)

- Configurable linker selection: empty/default for the linker bundled with
  LLVM, `auto` for the execution platform's native linker, or an explicit
  absolute path.

## [1.9.1](https://github.com/bazel-contrib/toolchains_llvm/tree/v1.9.1)

- Experimental C++ named modules, including `clang-scan-deps` integration.

## [1.9.0](https://github.com/bazel-contrib/toolchains_llvm/tree/v1.9.0)

- Explicit LLVM prerelease selection and prerelease-aware requirements.
- External JSONC distribution files and disabling the built-in LLVM catalogue.
- Direct zstd archive recognition.
- LeakSanitizer integration.

## [1.8.0](https://github.com/bazel-contrib/toolchains_llvm/tree/v1.8.0)

- JSONC distribution buckets and the named distribution helper scripts.
- Per-target toolchain roots through `target_toolchain_roots`.
- `extra_linker_files` and per-target extra-file extension tags.
- Expanded dynamic-libstdc++/Yocto sysroot layouts and SDK libc++ on Darwin.
- MSan with an instrumented libc++ overlay and the current sanitizer feature
  integration.
- Bare-metal RISC-V 64-bit targets.

## [1.7.0](https://github.com/bazel-contrib/toolchains_llvm/tree/v1.7.0)

- Custom rules-based C++ features via `extra_known_features` and
  `extra_enabled_features`.
- RISC-V 64-bit Linux targets.

## [1.6.0](https://github.com/bazel-contrib/toolchains_llvm/tree/v1.6.0)

- `first` / `latest` LLVM version requirements and environment-derived version
  requirements.
- Additive `extra_*` flag attributes.

## [1.5.0](https://github.com/bazel-contrib/toolchains_llvm/tree/v1.5.0)

- `extra_llvm_distributions`, including full URL/path entries.
- Header parsing and fastbuild compiler flags.
- Bare-metal x86-64 and RISC-V 32-bit targets.

## [1.4.0](https://github.com/bazel-contrib/toolchains_llvm/tree/v1.4.0)

- More convenience tool aliases.
- WebAssembly WASI Preview 1 and Linux ARMv7 targets.

## [1.3.0](https://github.com/bazel-contrib/toolchains_llvm/tree/v1.3.0)

- Initial `dynamic-stdc++` support.
- C-only compiler flags.
- Additional exported Clang tools/libraries.
- WebAssembly `wasm32-unknown-unknown` and `wasm64-unknown-unknown` targets.

## [1.2.0](https://github.com/bazel-contrib/toolchains_llvm/tree/v1.2.0)

- Custom platform constraints and optional libunwind linking.

## [1.1.0](https://github.com/bazel-contrib/toolchains_llvm/tree/v1.1.0)

- `llvm-profdata` support for coverage data merging.

## [1.0.0](https://github.com/bazel-contrib/toolchains_llvm/tree/1.0.0)

- Strict header dependencies through `layering_check`.
- Additional compiler sandbox inputs through `extra_compiler_files`.
- Explicit execution-platform configuration distinct from the configuring host.

## [0.9](https://github.com/bazel-contrib/toolchains_llvm/tree/0.9)

- Bzlmod integration.
- Per-host LLVM versions through `llvm_versions`.

## [0.8.1](https://github.com/bazel-contrib/toolchains_llvm/tree/0.8.1)

- Apple Silicon host support using LLVM 15 distributions.

## [0.8](https://github.com/bazel-contrib/toolchains_llvm/tree/0.8)

- `target_settings` for toolchain selection.
- An `llvm-symbolizer` target.

## [0.7](https://github.com/bazel-contrib/toolchains_llvm/tree/0.7)

- Per-platform download URLs/checksums and mirror configuration.
- C++ standard and standard-library selection, and flag overrides.
- Convenience `clang-format`, `llvm-cov`, and `omp` targets.

## [0.6](https://github.com/bazel-contrib/toolchains_llvm/tree/0.6)

- Bring Your Own LLVM through `toolchain_roots` and a separate LLVM distribution
  repository.
- Target-aware cross-compilation and AArch64 support.
- Authenticated downloads.
- Inheritance of Bazel's Unix toolchain configuration, including Linux ThinLTO.

## [0.4.4](https://github.com/bazel-contrib/toolchains_llvm/tree/0.4.4)

- Toolchain registration support.

## [0.4](https://github.com/bazel-contrib/toolchains_llvm/tree/0.4)

- Custom sysroots.

## [0.2](https://github.com/bazel-contrib/toolchains_llvm/tree/0.2)

- Automatic OS/distribution detection and explicit distribution selection.

## [0.1](https://github.com/bazel-contrib/toolchains_llvm/tree/0.1)

- Initial WORKSPACE-based LLVM toolchain.
- Explicit LLVM version selection.
- Absolute-path/sandbox configuration.

## Interpreting availability

- Introduction does not imply support for every Bazel version, LLVM release,
  platform, or later-added option. Consult the current README for requirements.
- Dynamic libstdc++ first appeared in 1.3.0; its expanded sysroot/Yocto support
  arrived in 1.8.0.
- MSan's instrumented-libc++ integration dates to 1.8.0. The C-instrumentation
  and unsupported-target fixes above do not make MSan a new 1.11.0 feature.
- Linux ThinLTO is inherited from Bazel/rules_cc, so its behavior also depends
  on those versions. The 1.11.0 addition is the macOS integration.
- Native and explicit-path linker selection shipped in 1.10.0. Downloadable
  catalogued linkers are a separate addition in 1.11.0.
- Zstd recognition arrived in 1.9.0; it does not guarantee that Bazel can
  extract every zstd archive. The 1.11.0 compatibility fix deliberately
  excludes zstd from automatic selection while retaining its metadata.
