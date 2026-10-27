---
name: melos-workspace-setup
description: >-
  Use when creating or configuring a Melos workspace: the root pubspec.yaml,
  the `melos` section, pub workspaces, `resolution: workspace`, bootstrap,
  shared dependencies, categories, `useRootAsPackage` and single package
  setups. Covers Melos 8.x, which is configured in pubspec.yaml, not
  melos.yaml.
---

# Melos workspace setup

Melos 8.x builds on [pub workspaces](https://dart.dev/tools/pub/workspaces).
All configuration lives in the `melos` section of the root `pubspec.yaml`.
There is no `melos.yaml` file anymore.

## Guidelines

- Put the workspace configuration in the root `pubspec.yaml`. Never create a
  `melos.yaml` file; Melos 7+ does not read it.
- List the packages in the `workspace` field of the root `pubspec.yaml`. Do
  not use a `melos.packages` list, that was removed in Melos 7.
- Add `resolution: workspace` to the `pubspec.yaml` of every package in the
  workspace.
- Add `melos` as a dev dependency of the root `pubspec.yaml`, so that
  everyone and CI use the same version. The globally activated `melos`
  switches to the version in the root `pubspec.yaml`.
- Set `publish_to: none` on the root `pubspec.yaml` unless the root is the
  package being published.
- Commit the root `pubspec.lock`.
- Globs in the `workspace` list need Dart 3.11 or newer. On older SDKs list
  every package path explicitly.
- Melos 8.x needs Dart 3.9 or newer.
- Run `melos bootstrap` (or `melos bs`) after changing the workspace. It runs
  `pub get`, syncs shared dependencies and runs the bootstrap hooks.
- Do not create `pubspec_overrides.yaml` files to link local packages. Pub
  workspaces link them. Melos only writes a root `pubspec_overrides.yaml` for
  `dependencyOverridePaths`.
- Keep the workspace root free of application code. If an app must live in
  the root, set `useRootAsPackage: true`.
- Use `melos init` to scaffold a new workspace instead of writing the files
  by hand.

## Minimal workspace

Root `pubspec.yaml`:

```yaml
name: my_workspace
publish_to: none
environment:
  sdk: ^3.9.0
workspace:
  - packages/helper
  - packages/client
  - apps/my_app
dev_dependencies:
  melos: ^8.0.0

melos:
  # Workspace configuration goes here.
```

Each package `pubspec.yaml`:

```yaml
name: helper
environment:
  sdk: ^3.9.0
resolution: workspace
```

Then:

```bash
dart pub global activate melos
melos bootstrap
```

## Common configuration

```yaml
melos:
  # Only needed when the top-level `repository` is not a plain URL, or for
  # self-hosted GitHub, GitLab, Bitbucket or Azure DevOps instances.
  repository: https://github.com/org/repo

  # Exclude packages from Melos (not from pub). Paths or globs.
  ignore:
    - packages/**/example

  # Group packages for the --category filter.
  categories:
    apps:
      - apps/*
    core:
      - packages/core_*

  # Dart/Flutter SDK to use, for example with FVM. "auto" uses the system SDK.
  sdkPath: .fvm/flutter_sdk

  # Only print warnings, errors and the output of failed commands.
  quiet: false

  # Include the repository root as a package.
  useRootAsPackage: false

  # Also discover packages inside nested pub workspaces.
  discoverNestedWorkspaces: false

  ide:
    intellij:
      enabled: true

  command:
    bootstrap:
      # Shared dependency versions, synced into every package that declares
      # the dependency on each bootstrap.
      environment:
        sdk: ^3.9.0
      dependencies:
        collection: ^1.19.0
      dev_dependencies:
        test: any
      # Add a comment to each synced entry in the package pubspecs.
      markSharedDependencies: true
      hooks:
        post: dart run build_runner build
```

Most command line options can be given a default under `command/<name>`,
usually under the camel cased option name, for example
`command/analyze/fatalInfos` or `command/test/concurrency`. The key differs
for some options (`bootstrap --offline` is `runPubGetOffline`,
`list --relative` is `relativePaths`) and some have none (`exec --sources`),
so check the configuration overview. Options on the command line take
precedence.

## Shared dependencies

Entries under `command/bootstrap/environment`, `dependencies` and
`dev_dependencies` are copied into every package that already declares that
dependency, every time `melos bootstrap` runs. Change the version in the root
`pubspec.yaml`, not in the packages, since the package value is overwritten.

## Dependency overrides to packages outside the workspace

```yaml
melos:
  command:
    bootstrap:
      dependencyOverridePaths:
        - ../other_repo/packages/**
```

Melos writes these as path overrides into the root `pubspec_overrides.yaml`
with a `melos_managed_dependency_overrides` marker and keeps unmanaged entries.

## Single package project

Melos works without a monorepo. Add it as a dev dependency and enable
`useRootAsPackage`; no `workspace` list is needed:

```yaml
name: my_app
publish_to: none
environment:
  sdk: ^3.9.0
dev_dependencies:
  melos: ^8.0.0

melos:
  useRootAsPackage: true
  command:
    version:
      # Private packages are skipped by `melos version` unless this is set
      # or `--all` is passed.
      versionPrivatePackages: true
```

The root package is tagged with plain `v1.2.3` tags instead of
`<package>-v1.2.3`.

## Flutter detection

A package is treated as a Flutter package, and `flutter` is used instead of
`dart` for `melos analyze`, `melos test` and the `--flutter` filter, when its
`pubspec.yaml` depends on an `sdk: flutter` package, declares a `flutter` SDK
constraint under `environment`, or depends on a workspace package that does.
A package that only needs Flutter through a hosted dependency should declare
the SDK constraint:

```yaml
environment:
  sdk: ^3.9.0
  flutter: ">=3.35.0"
```

## Anti-patterns

- `melos.yaml` with `name:` and `packages:` keys: Melos 6 format, no longer
  read. Move the content under `melos:` in the root `pubspec.yaml` and the
  packages into `workspace:`.
- `melos bootstrap` writing `pubspec_overrides.yaml` into each package: that
  was Melos 3 to 6 behaviour. Run `melos clean` once to remove the stale files.
- Forgetting `resolution: workspace` in a package: pub resolves the package
  on its own and the workspace does not link it.
- Editing a dependency version in a package while it is listed as a shared
  dependency: the next bootstrap overwrites it.
- Using `melos` from a global activation that differs from the version in the
  root `pubspec.yaml`: it is only a launcher, the workspace version runs.

## References

- Configuration overview:
  https://melos.invertase.dev/~melos-latest/configuration/overview
- Getting started:
  https://melos.invertase.dev/~melos-latest/getting-started
- Bootstrap command: https://melos.invertase.dev/~melos-latest/commands/bootstrap
- JSON schema for the `melos` section:
  https://raw.githubusercontent.com/invertase/melos/main/melos.yaml.schema.json
