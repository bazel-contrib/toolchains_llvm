# Migrating to toolchains_llvm 1.13.0

toolchains_llvm 1.13.0 changes prerelease eligibility and version comparisons
for `first` / `latest` selectors. Configurations selecting prereleases must
explicitly enable them and review their constraints. Exact version pins,
including RC pins, are unchanged.

For other changes, see the [1.13.0 changelog](../CHANGELOG.md#1130).
For the current configuration reference, see [Requirements](../README.md#requirements).

## Enable prereleases explicitly

In 1.12.x, `first` / `latest` selectors admitted prereleases only when a
requirement explicitly specified a prerelease version, and only for that
same major/minor/patch release. For example, a requirement naming
`23.1.0-rc1` admitted other 23.1.0 RCs, but not 23.1.1 or 24.1.0 RCs.

In 1.13.0, naming an RC in a requirement is no longer sufficient. Enable
prereleases with the corresponding attribute:

- LLVM: `llvm_version_allow_prereleases = True`.
- Catalogued linkers: `linker_version_allow_prereleases = True`.

Both flags default to `False` and are independent. They apply to bare and
constrained `first` / `latest` selectors, not exact pins. Use the same attributes
with `llvm.toolchain` in Bzlmod or `llvm_toolchain` in WORKSPACE; they are also
available in feature overrides. The linker flag has no effect on bundled
linkers, `auto`, or absolute executable paths.

The flag now controls prerelease eligibility separately from the constraints.
Those constraints no longer need to name an RC. Enabling prereleases admits
every prerelease satisfying them, not just prereleases with a release tuple
explicitly named in a requirement. For example, adding the flag to
`latest:>=23.1.0-rc1` also admits later releases' RCs. Review unbounded ranges
when migrating rather than only adding the flag.

Requirements and execution-host availability always apply. Selection uses
the configured LLVM or linker catalogue; it does not discover live upstream
releases. New candidates become available through a toolchains_llvm upgrade
or an explicit catalogue change.

## Choose the scope of RC upgrades

To follow LLVM 23.1.0 RCs and then select the final 23.1.0 release once its
archive is available for the execution host:

```starlark
llvm.toolchain(
    name = "llvm_rc",
    llvm_version = "latest:>23.0,<=23.1",
    llvm_version_allow_prereleases = True,
)
```

Choose the range according to the intended upgrade policy. These examples
all assume `llvm_version_allow_prereleases = True`:

| Selector                    | Upgrade policy                                            |
| --------------------------- | --------------------------------------------------------- |
| `latest:>23.0,<23.1`        | Admits 23.1.0 RCs, excludes final 23.1.0.                 |
| `latest:>23.0,<=23.1`       | Follows 23.1.0 RCs, then selects final 23.1.0.            |
| `latest:major==23,minor==1` | Follows all 23.1.x releases, including their prereleases. |

`23.1` means `23.1.0`, so `<=23.1` excludes 23.1.1 and its prereleases.
Stable releases within the constraints remain eligible; for example, the
two bounded ranges would also admit a 23.0.1 release if present in a custom catalogue.
Append `,is_prerelease()==True` if selection must be strictly prerelease-only.
With the flag set to `False`, only matching stable releases are eligible.
Conversely, `is_prerelease()==False` restricts a particular selector to stable
releases even when the flag is enabled.

The same constraints work for catalogued linkers through `linker_version`
with `linker_version_allow_prereleases = True`.

## Check RC ordering under SemVer

Version comparisons now use
[bzl's SemVer mode](https://mboworks.github.io/bzl/site/tag/0.8.0/docs/versions.html#semver).
[SemVer compares dot-separated prerelease identifiers](https://semver.org/#spec-item-11)
numerically when they contain only digits (`rc.2 < rc.10`), but lexically when
they contain letters (`rc10 < rc2`). `latest` follows that precedence, not
release chronology.

LLVM uses the undotted form for its 23.1.0 RCs, for example
[23.1.0-rc3](https://github.com/llvm/llvm-project/releases/tag/llvmorg-23.1.0-rc3),
not `23.1.0-rc.3`. Between matching `23.1.0-rc2` and hypothetical `23.1.0-rc10`,
`latest` would choose `rc2`. If LLVM instead used `23.1.0-rc.2` and
`23.1.0-rc.10`, `latest` would choose `rc.10`.

Both spellings are valid SemVer; they are not normalized into one another.
Mixing forms also matters: `23.1.0-rc.10 < 23.1.0-rc9`, because the first
identifier `rc` sorts before `rc9`. Switching from `rc9` to `rc.10` would
therefore leave `latest` selecting `rc9` if both remain eligible.

Use an exact pin if SemVer ordering differs from the intended upstream RC
order. Exact pins such as `llvm_version = "23.1.0-rc3"` do not require the
prerelease flag and bypass `first` / `latest` ordering.
