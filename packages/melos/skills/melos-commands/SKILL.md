---
name: melos-commands
description: >-
  Use when running Melos commands in a workspace or writing CI for one:
  `melos bootstrap`, `exec`, `run`, `analyze`, `format`, `test`, `list`,
  `changed`, `clean`, and the package filters shared by all of them such as
  `--scope`, `--diff`, `--depends-on`, `--flutter`, `--include-dependents`
  and `--post-filter`. Covers Melos 8.x.
---

# Melos commands and package filters

## Guidelines

- Run `melos` commands from anywhere inside the workspace; Melos finds the
  root `pubspec.yaml` with the `melos` section.
- Prefer the built-in `melos analyze`, `melos format` and `melos test` over
  `melos exec -- dart analyze` and friends. They pick `dart` or `flutter` per
  package, support all filters and summarise failures.
- Pass the command to `melos exec` after `--`, and pass multiple commands as
  one quoted string: `melos exec -- "dart format . && dart analyze ."`.
- Use filters to limit the packages instead of `cd`-ing into them.
- On CI, pass `--diff=origin/main...HEAD` to only test what changed, and add
  `--include-dependents` to also test the packages that depend on it.
- Use `--quiet` (or `quiet: true` in the configuration) on CI to only see the
  output of failing packages.
- Use `--verbose` to debug a command, for example `melos --verbose bootstrap`.
- Exit code 79 from `dart test` and `flutter test` (no tests ran) is treated
  as success, so packages without matching tests do not fail the run.

## Commands

```bash
melos init my_workspace          # Scaffold a workspace (pubspec.yaml, packages/, apps/)
melos bootstrap                  # pub get, sync shared deps, run bootstrap hooks (alias: bs)
melos bootstrap --no-pub         # Only sync shared deps, overrides and IDE files
melos bootstrap --enforce-lockfile
melos bootstrap --offline
melos clean                      # Remove temporary pub and IDE files, run clean hooks

melos exec -- dart pub upgrade   # Run a command in every package
melos exec -c 1 --fail-fast --order-dependents -- dart run build_runner build
melos exec --group-logs -- dart analyze .
melos exec --sources "lib/**.dart" --sources pubspec.yaml -- dart run build_runner build

melos run <script>               # Run a script from the root pubspec.yaml
melos <script>                   # Same, shorthand
melos run --list                 # List scripts (add --json for JSON)
melos run <script> --no-select   # Skip the package prompt of packageFilters

melos analyze --fatal-infos --fatal-warnings
melos format --output none --set-exit-if-changed   # CI formatting check
melos format --line-length 100
melos test                       # dart test / flutter test in every package with test/
melos test -c 4                  # Also passed as --concurrency to dart/flutter test

melos list                       # List packages (alias: ls)
melos list --long --relative
melos list --json | --parsable | --graph | --gviz | --mermaid
melos list --cycles              # Find dependency cycles
melos changed                    # Packages changed since their latest release tag
melos changed origin/main        # Packages changed since a ref
melos changed --include-dependents --json
```

`melos analyze`, `format` and `test` default to a concurrency of 1. Set
`command/<name>/concurrency` in the root `pubspec.yaml` to change the default.

## Package filters

Every command that supports filters accepts these. Options can be repeated.

| Flag | Selects packages that |
| --- | --- |
| `--scope=<glob>` | have a name matching the glob |
| `--ignore=<glob>` | do not have a name matching the glob |
| `--category=<name>` | belong to a category from the configuration |
| `--diff=<ref>` or `<a>...<b>` | changed between the ref (or range) and HEAD |
| `--dir-exists=<dir>` | contain the directory |
| `--file-exists=<file>` | contain the file (`$MELOS_PACKAGE_NAME` is expanded) |
| `--flutter` / `--no-flutter` | need, or do not need, the Flutter SDK |
| `--depends-on=<pkg>` | depend on the package |
| `--no-depends-on=<pkg>` | do not depend on the package |
| `--no-private` | are not `publish_to: none` |
| `--published` / `--no-published` | have, or have not, their current version on pub.dev |
| `--include-dependencies` | plus their transitive workspace dependencies |
| `--include-dependents` | plus their transitive workspace dependents |
| `--post-filter=<filter>` | apply a filter after the dependencies and dependents were added |

`--include-dependencies` and `--include-dependents` ignore the other filters
for the packages they add. Use `--post-filter` to filter the final set:

```bash
# Tests of the changed packages and everything that depends on them, but only
# where a test directory exists.
melos exec --diff=origin/main...HEAD --include-dependents \
  --post-filter=dir-exists=test -- dart test

# build_runner in a package and its dependencies that use build_runner.
melos exec --scope=my_app --include-dependencies \
  --post-filter=depends-on=build_runner -- dart run build_runner build
```

In `packageFilters` of a script the same filters are written in camel case
(`dirExists`, `dependsOn`, `includeDependents`, `postFilters`, ...).

`melos changed` takes the ref as its argument instead of `--diff`.

## Typical CI

```yaml
- run: dart pub global activate melos
- run: melos bootstrap --enforce-lockfile
- run: melos analyze --fatal-infos --fatal-warnings
- run: melos format --output none --set-exit-if-changed
- run: melos test --diff=origin/main...HEAD --include-dependents
```

The workspace `melos` dev dependency decides which version runs, so the
global activation does not need to be pinned.

## `--sources` for incremental commands

`melos exec --sources <glob>` stores a checksum of the matching files per
package after a successful run and skips the package next time if nothing,
including the sources of its workspace dependencies, changed. Combine it with
`--order-dependents` when the command generates files that match the sources.
`--run-unchanged` runs everywhere and still updates the checksums,
`--ignore-sources` disables the checksums entirely (useful on CI, also via
`MELOS_IGNORE_SOURCES=true` or `command/exec/ignoreSources`).

## Anti-patterns

- `melos exec dart analyze` without `--`: the arguments are parsed by Melos.
- `melos exec -- dart analyze && dart test`: the outer shell runs
  `dart test` once in the root. Quote the whole command instead.
- `melos exec -- echo $MELOS_PACKAGE_NAME` with double quotes or unquoted: the
  outer shell expands the variable to nothing. Use single quotes.
- `melos bootstrap` after every `pubspec.yaml` change in a package just to
  link it: pub workspaces link packages on `dart pub get`. Bootstrap is for
  shared dependencies, overrides and hooks.
- `--since`: removed in Melos 3, use `--diff`.
- Expecting `--include-dependents` to respect `--scope` for the added
  packages: it does not, use `--post-filter`.

## References

- Filters: https://melos.invertase.dev/~melos-latest/filters
- Commands: https://melos.invertase.dev/~melos-latest/commands/bootstrap and
  the sibling pages for `exec`, `run`, `analyze`, `format`, `test`, `list`,
  `changed`, `clean` and `init`
