<p align="center">
  <a href="https://melos.invertase.dev/~melos-latest">
  <img src="https://static.invertase.io/assets/melos-logo.png" alt="Melos" /> <br /><br />
  </a>
  <span>A tool for managing Dart projects with multiple packages, inspired by <a href="https://lerna.js.org">Lerna</a>.</span>
</p>

<p align="center">
  <a href="https://github.com/invertase/melos#readme-badge"><img src="https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square" alt="Melos" /></a>
  <a href="https://docs.page"><img src="https://img.shields.io/badge/powered%20by-docs.page-34C4AC.svg?style=flat-square" alt="docs.page" /></a>
 <a href="https://invertase.link/discord">
   <img src="https://img.shields.io/discord/295953187817521152.svg?style=flat-square&colorA=7289da&label=Chat%20on%20Discord" alt="Chat on Discord">
 </a>
</p>

<p align="center">
  <a href="https://melos.invertase.dev/~melos-latest">Documentation</a> &bull;
  <a href="https://github.com/invertase/melos/blob/main/LICENSE">License</a>
</p>

---

## About

Splitting up large code bases into separate independently versioned packages is
extremely useful for code sharing. However, making changes across many
repositories is _messy_ and difficult to track, and testing across repositories
gets complicated really fast.

To solve these (and many other) problems, some projects will organize their code
bases into multi-package repositories (sometimes called
[monorepos](https://en.wikipedia.org/wiki/Monorepo))

**Melos is a tool that optimizes the workflow around managing multi-package
repositories with git and Pub.**

## Github Action

If you're planning on using Melos in your GitHub Actions workflows, you can use
the [Melos Action](https://github.com/marketplace/actions/melos-action)
to run Melos commands, this action also supports automatic versioning and
publishing directly from your workflows.

## What does a Melos workspace look like?

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

The location of your packages can be configured via the `melos.yaml`
configuration file if the default is unsuitable.

## What can Melos do?

- 🔗 Link local packages in your workspace together without adding dependency
  overrides.
- 📦 Automatically version, create changelogs and publish your packages using
  [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).
- 📜 Pre-define advanced custom scripts for your workspace in your `melos.yaml`
  configuration to use via `melos run [scriptName]`. Anyone contributing to your
  workspace can just run `melos run` to be prompted to select a script from a
  list with descriptions of each script.
  - Scripts can even
    [prompt to select a package](https://melos.invertase.dev/~melos-latest/configuration/scripts#packagefilters)
    to run against with pre-defined filters.
- ⚡ Execute commands across your packages easily with
  `melos exec -- <command here>` with additional concurrency and fail-fast
  options.
  - [Environment variables](https://melos.invertase.dev/environment-variables)
    containing various information about the current package and the workspace
    are available in each execution.
  - Can be combined with all package filters.
- 🎯 Many advanced package filtering options allowing you to target specific
  packages or groups of packages in your workspace.
  - `--no-private`
    - Exclude private packages (`publish_to: none`).
  - `--[no-]published`
    - Filter packages where the current local package version exists on pub.dev.
      Or "-no-published" to filter packages that have not had their current
      version published yet.
  - `--[no-]nullsafety`
    - Filter packages where the current local version uses a "nullsafety"
      prerelease preid. Or "-no-nullsafety" to filter packages where their
      current version does not have a "nullsafety" preid.
  - `--[no-]flutter`
    - Filter packages where the package depends on the Flutter SDK. Or
      "-no-flutter" to filter packages that do not depend on the Flutter SDK.
  - `--scope=<glob>`
    - Include only packages with names matching the given glob.
  - `--ignore=<glob>`
    - Exclude packages with names matching the given glob.
  - `--diff=<ref>`
    - Only include packages that have been changed since the specified `ref`,
      e.g. a commit sha or git tag.
  - `--dir-exists=<dirRelativeToPackageRoot>`
    - Include only packages where a specific directory exists inside the
      package.
  - `--file-exists=<fileRelativeToPackageRoot>`
    - Include only packages where a specific file exists in the package.
  - `--depends-on=<dependantPackageName>`
    - Include only packages that depend on a specific package.
  - `--no-depends-on=<noDependantPackageName>`
    - Include only packages that _don't_ depend on a specific package.
  - `--include-dependencies`
    - Expands the filtered list of packages to include those packages'
      transitive dependencies (ignoring filters).
  - `--include-dependents`
    - Expands the filtered list of packages to include those packages'
      transitive dependents (ignoring filters).
- ♨️ Advanced support for IntelliJ IDEs with automatic creation of
  [run configurations for workspace defined scripts and more](https://melos.invertase.dev/~melos-latest/ide-support)
  on workspace bootstrap.
  - Integration with VS Code through an [extension][melos-code].

## Getting Started

Go to the
[Getting Started](https://melos.invertase.dev/~melos-latest/getting-started)
page of the [documentation](https://melos.invertase.dev/~melos-latest) to start
using Melos.

## Who is using Melos?

The following projects are using Melos:

- [firebase/flutterfire](https://github.com/firebase/flutterfire)
- [Flame-Engine/Flame](https://github.com/flame-engine/flame)
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
- [iapicca/yak_packages](https://github.com/iapicca/yak_packages)
- [atsign-foundation/at_app](https://github.com/atsign-foundation/at_app)
- [sub6resources/flutter_html](https://github.com/sub6resources/flutter_html)
- [ferraridamiano/ConverterNOW](https://github.com/ferraridamiano/ConverterNOW)
- [rrifafauzikomara/youtube_video](https://github.com/rrifafauzikomara/youtube_video)
- [mobxjs/mobx.dart](https://github.com/mobxjs/mobx.dart)
- [NetGlade/auto_mappr](https://github.com/netglade/auto_mappr)
- [myConsciousness/atproto.dart](https://github.com/myConsciousness/atproto.dart)
- [GrowERP Flutter ERP](https://github.com/growerp/growerp)
- [mrverdant13/coverde](https://github.com/mrverdant13/coverde)
- [ThexXTURBOXx/flutter_web_auth_2](https://github.com/ThexXTURBOXx/flutter_web_auth_2)
- [woltapp/wolt_modal_sheet](https://github.com/woltapp/wolt_modal_sheet)
- [cfug/dio](https://github.com/cfug/dio)
- [simolus3/drift](https://github.com/simolus3/drift)
- [Lyokone/flutterlocation](https://github.com/Lyokone/flutterlocation)
- [FlutterGen/flutter_gen](https://github.com/FlutterGen/flutter_gen)
- [canonical/ubuntu-desktop-provision](https://github.com/canonical/ubuntu-desktop-provision)
- [ubuntu/app-center](https://github.com/ubuntu/app-center)
- [jhomlala/alice](https://github.com/jhomlala/alice)
- [powersync/powersync.dart](https://github.com/powersync-ja/powersync.dart)
- [rodydavis/signals.dart](https://github.com/rodydavis/signals.dart)

> Submit a PR if you'd like to add your project to the list. Update the
> [README.md](https://github.com/invertase/melos/edit/main/packages/melos/README.md)
> and the [docs](https://github.com/invertase/melos/edit/main/docs/index.mdx).
>
> You can also add a [README badge](#readme-badge) to your projects README to
> let others know about Melos 💙.

## Documentation

Documentation is available at
[https://melos.invertase.dev](https://melos.invertase.dev/~melos-latest).

## Migrations

When migrating between major versions of Melos, please read the
[migration guide](https://melos.invertase.dev/~melos-latest/guides/migrations).

## Commands

Full commands list and args can be viewed by running `melos --help`.

```
> melos --help

A CLI tool for managing Dart & Flutter projects with multiple packages.

Usage: melos <command> [arguments]

Global options:
-h, --help        Print this usage information.
    --verbose     Enable verbose logging.
    --sdk-path    Path to the Dart/Flutter SDK that should be used. This command line option has
                  precedence over the `sdkPath` option in the `melos.yaml` configuration file and the
                  `MELOS_SDK_PATH` environment variable. To use the system-wide SDK, provide the
                  special value "auto".

Available commands:
  analyze     Analyzes all packages in your project for potential issues in a single run. Optionally
              configure severity levels. Supports all package filtering options.
  bootstrap   Initialize the workspace, link local packages together and install remaining package
              dependencies. Supports all package filtering options.
  clean       Clean this workspace and all packages. This deletes the temporary pub & ide files such
              as ".packages" & ".flutter-plugins". Supports all package filtering options.
  exec        Execute an arbitrary command in each package. Supports all package filtering options.
  format      Idiomatically format Dart source code.
  list        List local packages in various output formats. Supports all package filtering options.
  publish     Publish any unpublished packages or package versions in your repository to pub.dev. Dry
              run is on by default.
  run         Run a script by name defined in the workspace melos.yaml config file.
  version     Automatically version and generate changelogs based on the Conventional Commits
              specification. Supports all package filtering options.

Run "melos help <command>" for more information about a command.
```

## How to Contribute

To start making contributions please refer to
[`CONTRIBUTING.md`](./CONTRIBUTING.md).

## Lerna

This project is heavily inspired by [Lerna](https://lerna.js.org/).

## README Badge

Using Melos? Add a README badge to show it off:

[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

```markdown
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)
```

## License

- See [LICENSE](/LICENSE)

---

<p align="center">
  <a href="https://invertase.io/?utm_source=readme&utm_medium=footer&utm_campaign=melos">
    <img width="75px" src="https://static.invertase.io/assets/invertase/invertase-rounded-avatar.png">
  </a>
  <p align="center">
    Built and maintained with 💛 by <a href="https://invertase.io/?utm_source=readme&utm_medium=footer&utm_campaign=melos">Invertase</a>.
  </p>
    <p align="center">
    &nbsp;&nbsp;<a href="https://twitter.com/invertaseio"><img src="https://img.shields.io/twitter/follow/invertaseio.svg?style=flat-square&colorA=1da1f2&colorB=&label=Follow%20on%20Twitter" alt="Follow on Twitter"></a>
  </p>
</p>

[melos-code]:
  https://marketplace.visualstudio.com/items?itemName=blaugold.melos-code
