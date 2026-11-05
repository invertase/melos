---
name: melos-scripts
description: >-
  Use when defining or editing Melos scripts in the `melos.scripts` section
  of the root pubspec.yaml: `run` versus `exec`, `exec` options such as
  `concurrency` and `orderDependents`, `packageFilters`, `env`, `steps`,
  `dependsOn`, `sources`, `private`, `groups`, `stdio`, command hooks and
  the MELOS_* environment variables. Covers the Melos 8.x script format.
---

# Melos scripts

Scripts are defined under `melos.scripts` in the root `pubspec.yaml` and run
with `melos run <name>` or directly as `melos <name>`.

## Guidelines

- The script name is the key in the `scripts` map. There is no `name` field.
- A script is either `run` (runs once, in the workspace root) or `exec` (runs
  in every selected package through `melos exec`). Never set both.
- To pass options to `exec`, make `exec` a map with the command under
  `command`. Do not put the command in `run` next to an `exec` map, that is
  the Melos 7 format and Melos 8 rejects it.
- Filter names in `packageFilters` are camel cased: `dirExists`,
  `fileExists`, `dependsOn`, `noDependsOn`, `flutter`, `noPrivate`,
  `published`, `scope`, `ignore`, `category`, `diff`, `includeDependencies`,
  `includeDependents`, `postFilters`. Never use kebab case or the old
  `select-package` key.
- Scripts run in `sh` (and `cmd.exe` on Windows). Chain commands with `&&`
  so that a failure stops the script.
- Always add a `description`; it is shown in `melos run` and in generated IDE
  run configurations.
- Hooks go under `command/<name>/hooks`, not in `scripts`. The old
  `postbootstrap` and `postclean` script names are not hooks anymore.
- Reference `env` and `MELOS_*` variables as `$VAR` or `${VAR}` for
  cross-platform scripts.
- In an `exec` script, escape command substitutions that need the package
  variables, for example `\$(basename $MELOS_PACKAGE_PATH)`, since an
  unescaped one runs once before `melos exec` starts.
- A custom script with the same name as a built-in command overrides that
  command, for both `melos <name>` and `melos run <name>`.

## Script forms

```yaml
melos:
  scripts:
    # Shorthand: name and command only.
    hello: echo 'Hello World'

    # Runs once in the workspace root.
    prepare:
      description: Bootstrap and generate code.
      run: melos bootstrap && melos run generate

    # Runs in every package, with the default exec options.
    analyze:
      description: Analyze every package.
      exec: dart analyze .

    # Runs in every package, with exec options.
    test:
      description: Run the tests of every package that has a test directory.
      exec:
        command: dart test
        concurrency: 1
        failFast: true
      packageFilters:
        dirExists: test
      env:
        CI: "true"

    # Code generation, ordered by the dependency graph and skipped in packages
    # whose sources did not change since the last successful run.
    generate:
      description: Generate code with build_runner.
      exec:
        command: dart run build_runner build --delete-conflicting-outputs
        orderDependents: true
        sources:
          - lib/**.dart
          - pubspec.yaml
      packageFilters:
        dependsOn: build_runner
```

### `exec` options

- `command`: the command, required when `exec` is a map.
- `concurrency`: packages to run in at once. Defaults to the processor count.
- `failFast`: stop after the first failing package. Defaults to `false`.
- `orderDependents`: run in dependencies before dependents. Defaults to
  `false`. Required for scripts that generate files that match `sources`.
- `groupLogs`: buffer the output and print it per package when all finished,
  failures last. Defaults to `false`.
- `sources`: globs relative to each package root. The script is skipped in
  packages where none of the matching files, or those of their workspace
  dependencies, changed since the last success. Checksums live in
  `.dart_tool/melos/fingerprints`. `melos run <name> --run-unchanged` runs
  everywhere anyway, `--ignore-sources` disables the checksums.

Defaults for all `exec` scripts can be set under `command/exec` in the root
`pubspec.yaml`.

## `packageFilters` with `run`

A `run` script always executes once. `packageFilters` on a `run` script only
sets `MELOS_PACKAGES` for the `melos` command that the script invokes, so it
scopes a nested `melos exec`. If the script does not call `melos`, the filters
only produce a package prompt and have no effect. Use `exec` to run a command
per package.

```yaml
scripts:
  analyze_lib:
    run: melos exec -- dart analyze
    packageFilters:
      dirExists: lib
```

When a script has `packageFilters`, `melos run` prompts to select one package
or all of them. Skip the prompt with `melos run <name> --no-select` or set
`command/run/noSelect: true`.

## Composition

```yaml
scripts:
  # Sequential steps. Each step is a script name or a shell command.
  pre-commit:
    description: Format, analyze and test.
    steps:
      - format --output none --set-exit-if-changed
      - analyze
      - test

  # Dependency graph. Shared dependencies run once.
  verify:
    description: Generate once, then build and test.
    dependsOn:
      - build
      - test
  build:
    run: dart run tool/build.dart
    dependsOn:
      - generate
  test:
    exec: dart test
    dependsOn:
      - generate

  # Only reachable from steps or dependsOn, hidden from prompts.
  generate:
    exec: dart run build_runner build
    private: true

  # Scripts can be grouped for `melos run --group ci`.
  lint:
    exec: dart analyze .
    groups:
      - ci
```

`steps` and `dependsOn` cannot carry `exec` options or `packageFilters`; set
them on the individual scripts. `dependsOn` is not supported on hooks. Extra
arguments passed to `melos run` only reach the requested script.

## Interactive scripts

Scripts are piped by default so Melos can prefix their output. A script that
needs a real terminal, such as `flutter run` with hot reload keys, must set
`stdio: inherit`. It cannot be combined with `exec` or `steps`.

```yaml
scripts:
  dev:
    run: flutter run
    stdio: inherit
```

## Hooks

```yaml
melos:
  command:
    bootstrap:
      hooks:
        pre: echo "bootstrapping"
        post: dart run build_runner build
    clean:
      hooks:
        post: melos exec --flutter -- flutter clean
    version:
      hooks:
        # Runs after pubspecs and changelogs are updated, before the version
        # commit. Stage any files you change yourself.
        preCommit: dart run tool/update_version_constant.dart && git add lib/version.dart
        post: echo "versioned"
    publish:
      hooks:
        pre: dart run build_runner build
        post: dart run build_runner clean
```

`bootstrap`, `clean`, `version` and `publish` support `pre` and `post`.
`version` additionally supports `preCommit`. The publish hooks also run on a
dry run; check `MELOS_PUBLISH_DRY_RUN` to tell the two apart.

## Environment variables

Available in `melos exec` and `exec` scripts: `MELOS_ROOT_PATH`,
`MELOS_PACKAGE_NAME`, `MELOS_PACKAGE_VERSION`, `MELOS_PACKAGE_PATH`, and for
`example` packages `MELOS_PARENT_PACKAGE_NAME`, `MELOS_PARENT_PACKAGE_VERSION`
and `MELOS_PARENT_PACKAGE_PATH`.

User settable: `MELOS_PACKAGES` (comma separated scope), `MELOS_SDK_PATH`,
`MELOS_QUIET`, `MELOS_RUN_UNCHANGED`, `MELOS_IGNORE_SOURCES`,
`MELOS_ANSI_STYLES`.

From a terminal, quote the command so that the outer shell does not expand
the package variables first:

```bash
melos exec -- 'echo $MELOS_PACKAGE_NAME'
```

## Reusing configuration with YAML anchors

Keys prefixed with `x-` are ignored by Melos and can hold anchors. YAML merge
keys (`<<`) are not supported, an alias replaces a whole value:

```yaml
melos:
  scripts:
    x-analyze: &analyze
      exec:
        command: dart analyze .
        concurrency: 1
    analyze: *analyze
```

## Anti-patterns

```yaml
# Wrong: Melos 7 format, rejected by Melos 8.
test:
  run: dart test
  exec:
    concurrency: 1

# Right
test:
  exec:
    command: dart test
    concurrency: 1

# Wrong: kebab case and the removed select-package key.
test:
  exec: dart test
  select-package:
    dir-exists: test

# Right
test:
  exec: dart test
  packageFilters:
    dirExists: test

# Wrong: hooks as scripts (Melos 2 format).
scripts:
  postbootstrap: dart run build_runner build

# Right
command:
  bootstrap:
    hooks:
      post: dart run build_runner build
```

## References

- Scripts: https://melos.invertase.dev/~melos-latest/configuration/scripts
- Environment variables:
  https://melos.invertase.dev/~melos-latest/environment-variables
- Run command: https://melos.invertase.dev/~melos-latest/commands/run
