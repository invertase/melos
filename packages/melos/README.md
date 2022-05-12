<p align="center">
  <img src="https://static.invertase.io/assets/melos-logo.png" alt="Melos" /> <br /><br />
  <span>A tool for managing Dart projects with multiple packages.</span>
</p>

---

## About

Splitting up large code bases into separate independently versioned packages is extremely useful for code sharing.
However, making changes across many repositories is _messy_ and difficult to track, and testing across repositories gets
complicated really fast.

To solve these (and many other) problems, some projects will organize their code
bases into multi-package repositories (sometimes called
[monorepos](https://en.wikipedia.org/wiki/Monorepo))

**Melos is a tool that optimizes the workflow around managing multi-package repositories with git and Pub.**

---

### What does a Melos workspace look like?

A default file structure looks something like this:

```
my-melos-repo/
  melos.yaml
  packages/
    package-1/
      pubspec.yaml
    package-2/
      pubspec.yaml
```

The location of your packages can be configured via the `melos.yaml` configuration file if the default is unsuitable.

---

### What can Melos do?

- 🔗 Link local packages in your workspace together without adding dependency overrides.
- 📦 Automatically version, create changelogs and publish your packages
  using [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).
- 📜 Pre-define advanced custom scripts for your workspace in your `melos.yaml` configuration to use
  via `melos run [scriptName]`. Anyone contributing to your workspace can just run `melos run` to be prompted to select
  a script from a list with descriptions of each script.
    - Scripts can even [prompt to select a package](https://github.com/invertase/melos/pull/34) to run against with
      pre-defined filters.
- ⚡ Execute commands across your packages easily with `melos exec -- command here` with additional concurrency and
  fail-fast options.
    - [Environment variables](https://github.com/invertase/melos/issues/3) containing various information about the
      current package and the workspace are available in each execution.
    - Can be combined with all package filters.
- 🎯 Many advanced package filtering options allowing you to target specific packages or groups of packages in your
  workspace.
    - `--no-private`
        - Exclude private packages (`publish_to: none`).
    - `--[no-]published`
        - Filter packages where the current local package version exists on pub.dev. Or "-no-published" to filter
          packages that have not had their current version published yet.
    - `--[no-]nullsafety`
        - Filter packages where the current local version uses a "nullsafety" prerelease preid. Or "-no-nullsafety" to
          filter packages where their current version does not have a "nullsafety" preid.
    - `--[no-]flutter`
        - Filter packages where the package depends on the Flutter SDK. Or "-no-flutter" to filter packages that do not
          depend on the Flutter SDK.
    - `--scope=<glob>`
        - Include only packages with names matching the given glob.
    - `--ignore=<glob>`
        - Exclude packages with names matching the given glob.
    - `--since=<ref>`
        - Only include packages that have been changed since the specified `ref`, e.g. a commit sha or git tag.
    - `--dir-exists=<dirRelativeToPackageRoot>`
        - Include only packages where a specific directory exists inside the package.
    - `--file-exists=<fileRelativeToPackageRoot>`
        - Include only packages where a specific file exists in the package.
    - `--depends-on=<dependantPackageName>`
        - Include only packages that depend on a specific package.
    - `--no-depends-on=<noDependantPackageName>`
        - Include only packages that *don't* depend on a specific package.
- ♨️ Advanced support for IntelliJ IDEs with automatic creation
  of [run configurations for workspace defined scripts and more](https://github.com/invertase/melos/issues/9) on
  workspace boostrap.
    - Vscode code doesn't require advanced integration to work.

---

### Who is using Melos?

The following projects are using Melos:

- [FirebaseExtended/flutterfire](https://github.com/FirebaseExtended/flutterfire)
- [Flame-Engine/Flame](https://github.com/flame-engine/flame)
- [aws-amplify/amplify-flutter](https://github.com/aws-amplify/amplify-flutter)
- [fluttercommunity/plus_plugins](https://github.com/fluttercommunity/plus_plugins)
- [GetStream/stream-chat-flutter](https://github.com/GetStream/stream-chat-flutter)
- [4itworks/opensource_qwkin_dart](https://github.com/4itworks/opensource_qwkin_dart)
- [gql-dart/ferry](https://github.com/gql-dart/ferry)
- [cbl-dart/cbl-dart](https://github.com/cbl-dart/cbl-dart)
- [ema987/paddinger](https://github.com/ema987/paddinger)
- [flutter-stripe/flutter_stripe](https://github.com/flutter-stripe/flutter_stripe)
- [danvick/flutter_form_builder](https://github.com/danvick/flutter_form_builder)
- [kmartins/groveman](https://github.com/kmartins/groveman)
- [flutternetwork/WiFiFlutter](https://github.com/flutternetwork/WiFiFlutter)

> Submit a PR if you'd like to add your project to the list.
> Update the [README.md](https://github.com/invertase/melos/edit/main/packages/melos/README.md) and the
> [docs](https://github.com/invertase/melos/edit/main/docs/index.mdx).
> You can also add a [readme badge](#readme-badge) to your projects readme to let others know about Melos 💙.

---

## Getting Started

Install the latest Melos version as a global package via [Pub](https://pub.dev/).

```bash
dart pub global activate melos

# Or alternatively to specify a specific version:
# pub global activate melos 0.4.1
```

---

### Documentation

Documentation is available at [https://docs.page/invertase/melos](https://docs.page/invertase/melos).

---

### Commands

Full commands list and args can be viewed by running `melos --help`.

```
> melos --help

A CLI tool for managing Dart & Flutter projects with multiple packages.

Usage: melos <command> [arguments]

Global options:
-h, --help                                       Print this usage information.
    --verbose                                    Enable verbose logging.
    --no-private                                 Exclude private packages (`publish_to: none`). They are included by default.
    --[no-]published                             Filter packages where the current local package version exists on pub.dev. Or "-no-published" to filter packages that have not had their current version published yet.
    --[no-]flutter                               Filter packages where the package depends on the Flutter SDK. Or "-no-flutter" to filter packages that do not depend on the Flutter SDK.
    --scope=<glob>                               Include only packages with names matching the given glob. This option can be repeated.
    --ignore=<glob>                              Exclude packages with names matching the given glob. This option can be repeated.
    --since=<ref>                                Only include packages that have been changed since the specified `ref`, e.g. a commit sha or git tag.
    --dir-exists=<dirRelativeToPackageRoot>      Include only packages where a specific directory exists inside the package.
    --file-exists=<fileRelativeToPackageRoot>    Include only packages where a specific file exists in the package.
    --depends-on=<dependantPackageName>          Include only packages that depend on a specific package. This option can be repeated.
    --no-depends-on=<noDependantPackageName>     Include only packages that *don't* depend on a specific package. This option can be repeated.

Available commands:
  bootstrap   Initialize the workspace, link local packages together and install remaining package dependencies. Supports all package filtering options.
  clean       Clean this workspace and all packages. This deletes the temporary pub & ide files such as ".packages" & ".flutter-plugins". Supports all package filtering options.
  exec        Execute an arbitrary command in each package. Supports all package filtering options.
  list        List local packages in various output formats. Supports all package filtering options.
  publish     Publish any unpublished packages or package versions in your repository to pub.dev. Dry run is on by default.
  run         Run a script by name defined in the workspace melos.yaml config file.
  version     Automatically version and generate changelogs based on the Conventional Commits specification. Supports all package filtering options.

Run "melos help <command>" for more information about a command.
```

---

## Lerna

This project is heavily inspired by [Lerna](https://lerna.js.org/).

---

## README Badge

Using Melos? Add a README badge to show it off:

[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

```markdown
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)
```

---

## License

- See [LICENSE](/LICENSE)

---

<p>
  <img align="left" width="75px" src="https://static.invertase.io/assets/invertase-logo-small.png">
  <p align="left">
    &nbsp;&nbsp;Built and maintained with 💛 by <a href="https://invertase.io">Invertase</a>.
  </p>
  <p align="left">
    &nbsp;&nbsp;<a href="https://twitter.com/invertaseio"><img src="https://img.shields.io/twitter/follow/invertaseio.svg?style=flat-square&colorA=1da1f2&colorB=&label=Follow%20on%20Twitter" alt="Follow on Twitter"></a>
  </p>
</p>

---
