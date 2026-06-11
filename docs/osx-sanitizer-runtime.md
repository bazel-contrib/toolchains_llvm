# macOS sanitizer runtime loading — findings

Investigation into why `--features=asan` fails at runtime on macOS
([#192](https://github.com/bazel-contrib/toolchains_llvm/issues/192)), and a
comparison of two fixes:

- **A. Post-link rpath rewrite** (PR
  [#767](https://github.com/bazel-contrib/toolchains_llvm/pull/767), branch
  `osx-sanitizer-runtime-rpath`): after linking, add an `@loader_path`-relative
  `LC_RPATH` pointing back to the toolchain's compiler-rt directory.
- **B. `dynamic_runtime_lib`** (branch `osx-sanitizer-dynamic-runtime-lib`,
  this document's branch): expose the sanitizer runtime dylib through the
  `cc_toolchain.dynamic_runtime_lib` attribute so Bazel links it via the solib
  directory and ships it in the binary's runfiles.

Both were validated against the full `helly25/mbo` test suite (74 test
targets) on macOS 26 / Apple Silicon with LLVM 22.1.7, using
`--override_module=toolchains_llvm=<local checkout>` and mbo's
`--config=clang --config=asan`.

## The problem

On macOS the sanitizer runtimes are **dynamic-only**: linking with
`-fsanitize=address` (or thread/undefined) records
`@rpath/libclang_rt.asan_osx_dynamic.dylib` in the binary (the dylib's install
name), and Clang adds a _toolchain-relative_ `LC_RPATH`
(`external/<llvm repo>/lib/clang/<v>/lib/darwin`). That path is resolved
relative to the process's working directory, so it only works when the binary
runs from the execroot — true at link time, false when `bazel test` runs the
binary from its runfiles:

```
dyld: Library not loaded: @rpath/libclang_rt.asan_osx_dynamic.dylib
```

On Linux this problem does not exist because the sanitizer runtimes are static
archives linked into the binary.

## Approach A: post-link `@loader_path` rpath (PR #767)

The osx wrapper (`osx_cc_wrapper.sh.tpl`) checks the linked output with
`otool -L`; if it references `@rpath/libclang_rt.*`, it adds an
`LC_RPATH` of the form `@loader_path/<../ per output-dir component>/external/
<llvm repo>/lib/clang/<v>/lib/darwin` via `install_name_tool -add_rpath`.
`@loader_path` resolves relative to the binary's real path (runfiles entries
are symlinks into the execroot), so the toolchain directory is found no matter
the working directory.

**Validation: 74/74 mbo asan tests pass.**

Properties:

- Covers **all link modes** — `cc_test`, `cc_binary` (default
  `linkstatic = 1`), binaries run via `sh_test`/`data`.
- No change to link inputs or runfiles; zero overhead for non-sanitized
  builds (the rewrite only fires when a sanitizer runtime is referenced).
- **Local-execution only**: the rpath points back into the build machine's
  execroot (`external/...`). It breaks for remote execution, for
  `--remote_download_minimal`, and for binaries copied out of `bazel-out`.

## Approach B: `dynamic_runtime_lib` (this branch)

### How the mechanism works (rules_cc / Bazel 9)

- `cc_toolchain.{static,dynamic}_runtime_lib` are only consulted when the
  feature **`static_link_cpp_runtimes`** is enabled
  (`cc_toolchain_info.bzl`); with the feature on, _both_ attributes must be
  set or analysis fails.
- The choice between them follows the **linking mode**
  (`cc_binary.bzl: _get_link_staticness`):
  - `cc_test` defaults to `linkstatic = False` on non-Windows →
    `LINKING_DYNAMIC` → `dynamic_runtime_lib` is linked (as a
    `library_to_link(dynamic_library = ...)` via the solib directory) **and
    added to the test's runfiles**.
  - `cc_binary` defaults to `linkstatic = True` → `LINKING_STATIC` →
    `static_runtime_lib` is used; nothing reaches runfiles.
- On darwin, rules_cc's `runtime_library_search_directories` feature emits
  dyld-native `@loader_path/...` rpaths (the `$ORIGIN` form is Linux-only),
  so no wrapper post-processing is needed.
- The stock `static_link_cpp_runtimes` feature is defined (disabled) inside
  `unix_cc_toolchain_config` and cannot be enabled from outside directly:
  `extra_enabled_features` drops external feature references
  (`legacy_converter.bzl: convert_feature` returns `None` for
  `feature.external`). It **can** be enabled transitively: a `cc_feature`
  that `implies` the predefined
  `@rules_cc//cc/toolchains/features:static_link_cpp_runtimes` target.

### Implementation (3 files)

1. `toolchain/BUILD.llvm_repo.tpl` — filegroups
   `libclang_rt-{asan,tsan,ubsan}-darwin` globbing
   `lib/clang/<v>/lib/darwin/libclang_rt.<san>_osx_dynamic.dylib`
   (empty on non-darwin distributions).
2. `toolchain/cc_toolchain_config.bzl` — darwin-only `cc_feature`
   `<name>_sanitizer_runtime_runfiles` that `implies`
   `static_link_cpp_runtimes`, wired into `extra_enabled_features` under a
   `select()` on the existing `use_asan`/`use_ubsan`/`use_tsan`
   config settings (which match `--features=...`, so exec-configuration
   builds stay unaffected).
3. `toolchain/internal/configure.bzl` — the generated `cc_toolchain` sets
   `static_runtime_lib` (empty filegroup) and `dynamic_runtime_lib`
   (`select()` picking the matching sanitizer dylib filegroup). Scoped to
   darwin hermetic toolchains; the host toolchain finds its runtime at its
   absolute location.

### Validation: 73/74 mbo asan tests pass

The resulting `cc_test` binary gets exactly the right structure — three
`@loader_path` rpaths covering both execution contexts, plus the dylib
physically present in runfiles:

```
$ otool -l no_destruct_test | grep -A2 LC_RPATH | grep path
  @loader_path/../../_solib_<toolchain>/                                 # from bazel-bin
  @loader_path/no_destruct_test.runfiles/_main/_solib_<toolchain>/      # as test
  @loader_path/_solib_<toolchain>/
  @executable_path
  external/<llvm repo>/lib/clang/22/lib/darwin                           # Clang's own (cwd-relative)

$ ls no_destruct_test.runfiles/_main/_solib_<toolchain>/
libclang_rt.asan_osx_dynamic.dylib
```

The **one failure** is structural, not a bug: `//mbo/file:glob_sh_test` is an
`sh_test` that runs a `cc_binary` (`mbo/file/glob`) from its runfiles. The
binary links in static mode (`linkstatic = 1` default) → takes the
`static_runtime_lib` branch (empty — macOS has **no static asan runtime**) →
keeps only Clang's cwd-relative rpath → `Abort trap: 6` at load. Approach A
covers this case; approach B cannot, short of requiring `linkstatic = 0` on
sanitized binaries.

## Side finding: LLVM 20.1.8 asan deadlocks at init on macOS 26

Independent of either fix: 20.1.8's compiler-rt hangs (100 % CPU spin before
`main`) under asan on macOS 26. Sampled stack:
`__asan::AsanInitInternal → InitializeShadowMemory → MemoryRangeIsAvailable →
get_dyld_hdr → dyld_shared_cache_iterate_text_swift (new Swift dyld API) →
_Block_copy → malloc` — which re-enters the asan-wrapped malloc zone and
spins on the init `StaticSpinMutex` already held by the outer init.
Fixed in later compiler-rt; mbo's CI already excludes the combo and runs
macOS asan on LLVM ≥ 21. Any macOS asan testing must use 21.1.8+/22.1.7.

## Comparison

|                                                                    | A: wrapper rpath (#767)               | B: `dynamic_runtime_lib`             |
| ------------------------------------------------------------------ | ------------------------------------- | ------------------------------------ |
| `cc_test` (default linkstatic=0)                                   | ✅                                    | ✅                                   |
| `cc_binary` (default linkstatic=1), incl. run via `sh_test`/`data` | ✅                                    | ❌ (no static asan runtime on macOS) |
| Binary copied out of bazel-out / deployed                          | ❌                                    | ✅ (dylib travels in runfiles)       |
| Remote execution / `--remote_download_minimal`                     | ❌                                    | ✅ for tests                         |
| Mechanism                                                          | post-link `install_name_tool` surgery | Bazel's designed runtime-lib channel |
| Non-sanitized builds affected                                      | no                                    | no (feature select-gated)            |
| mbo asan suite                                                     | 74/74                                 | 73/74                                |

The approaches are **complementary**: A covers static-mode binaries on local
machines; B makes the runtime travel with tests (correct for remote execution
and moved binaries) using the supported Bazel mechanism. They compose without
interference — with both active, static-mode binaries resolve via A's rpath
and dynamic-mode tests prefer the runfiles copy.

## Outlook: libc++

`static_link_cpp_runtimes` + `{static,dynamic}_runtime_lib` is the _designed_
mechanism for shipping the C++ standard library runtime. On darwin this
toolchain currently falls back to the SDK's libc++
(`cc_toolchain_config.bzl`, "use the SDK's libc++ entirely") precisely because
the toolchain's `libc++.dylib` has an unresolvable `@rpath` install name —
the same root cause as the sanitizer issue. Unlike the sanitizers, **both**
branches have real artifacts there (`libc++.a` / `libc++.dylib`), so extending
this branch's wiring to the standard library would allow hermetic libc++ on
macOS in both link modes. That is the natural follow-up.

## Sharp edges / caveats

- Combining sanitizers (`--features=asan --features=ubsan`) makes both
  `config_setting`s match and the `select()` fail as ambiguous. This is
  **pre-existing** (the `sanitizer_link_flags` select in
  `cc_toolchain_config.bzl` has the same shape) and matches Clang's model
  (one runtime per link), but the error message is obscure.
- `extra_enabled_features` silently drops `cc_external_feature` references —
  enabling a legacy feature requires the `implies` indirection used here.
- Scope: hermetic (downloaded) toolchains only; `absolute_paths` /host
  toolchains are unchanged by either approach.
