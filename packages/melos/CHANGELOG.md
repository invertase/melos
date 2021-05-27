## 0.4.11+1

 - **REFACTOR**: remove MelosCommandRunner.instance (#107).
 - **FIX**: when executing a command inside a package, melos now properly executes it on all packages of the workspace. (#108).

## 0.4.11

 - **REFACTOR**: Move to a stubbable Platform abstraction (#86).
 - **FIX**: The default workspace no-longer searches for projects inside the .dart_tool folder of packages (#104).
 - **FIX**: incorrect intellij project clean glob pattern in windows (#97).
 - **FEAT**: Added support for calling melos commands from anywhere inside a melos workspace (#103).
 - **FEAT**: `melos bootstrap` now executes generates its temporary project inside the .dart_tool folder (#106).
 - **FEAT**: add --yes flag to `melos publish` (#105).
 - **FEAT**: make intellij project clean only delete melos run configurations (#96).
 - **DOCS**: Add cofu-app/cbl-dart to users of Melos (#95).
 - **DOCS**: add gql-dart/ferry as melos user.

## 0.4.10+1

 - **REFACTOR**: add missing license headers.
 - **FIX**: use original pubspec.lock files when running pub get inside mirrored workspace (fixes #68).

## 0.4.10

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 0.4.10-dev.1

> Note: This release has breaking changes.

 - **FIX**: Fix --published/--no-published filters.
 - **FIX**: Find templates using a resolved package URI.
 - **BREAKING** **FEAT**: Use PUB_HOSTED_URL as pub.dev alternative if defined.

## 0.4.10-dev.0

 - **TEST**: Add a couple of useful matchers.
 - **TEST**: Add mock filesystem facilities to aid in testing.
 - **STYLE**: Rearrange some methods in MelosPackage.
 - **STYLE**: Wrap option description strings.
 - **REFACTOR**: Clean up the MelosWorkspace, and ensure a package catch-all.
 - **FEAT**: Add filtering flags for including dependendies and dependents.
 - **DOCS**: Rewrapped melos README to avoid an unfortunate space.
 - **CHORE**: Add missing copyright.
 - **BUILD**: Upgrade package dependencies.

## 0.4.9

 - **REFACTOR**: Clean up workspace code in preparation for command config implementation (#77).
 - **FEAT**: Add melos.yaml support for the version command's message default.
 - **FEAT**: Add melos.yaml command configuration.

## 0.4.8+1

 - **FIX**: Newline handling for version's message option (#73).

## 0.4.8

 - **REFACTOR**: Improve styling of command usage (#71).
 - **FEAT**: Support configurable commit messages in version command (#72).

## 0.4.7

 - **FEAT**: allow private packages to be versioned (#67).

## 0.4.6

 - **FEAT**: allow --yes to also skip prompts when manually versioning (closes #66).

## 0.4.5+3

 - Update a dependency to the latest release.

## 0.4.5+2

 - **FIX**: certain generated yaml file keys can be null.
 - **FIX**: some dependent packages were not visible when graduating with a filter.
 - **DOCS**: Add GetStream/stream-chat-flutter as a user of melos (#63).

## 0.4.5+1

 - **FIX**: script select-package ignore filter was not including ignores also defined in melos.yaml.

## 0.4.5

 - **FEAT**: allow listing packages in Graphviz DOT language (#58).

## 0.4.4+2

 - **FIX**: hook scripts not working.
 - **FIX**: non-nullsafety pre-major prerelease should also bump it's minor version (#55).

## 0.4.4+1

 - **DOCS**: add monorepo to pub description.

## 0.4.4

 - **FEAT**: show latest registry prerelease version of the same preid in `publish` command if the local version is also a prerelease.
 - **CHORE**: format changelog.

## 0.4.3

- **FEAT**: add new `--[no-]nullsafety` package filtering option
- **FEAT**: introduce `dependent-versions` & `dependent-constraints` versioning flags

## 0.4.2

- **FEAT**: allow manually versioning a specific package via `melos version` (#53).

## 0.4.1

- **FEAT**: rework versioning with tests to support nullsafety prerelease versioning (#52).
- **CHORE**: improve local development setup + add small guide to readme.
- **CHORE**: use latest conventional_commit package.

## 0.4.0+1

- Update a dependency to the latest release.

## 0.4.0

> Note: This release has breaking changes.

- **BREAKING** **REFACTOR**: rework bootstrap behaviour (see #51 for more info).

## 0.3.13

- **FEAT**: add `flutter` package filter (#45).

## 0.3.12+1

- **FIX**: don't recreate currentWorkspace if already created (fixes #39) (#40).
- **CHORE**: correctly git add version.g.dart.

## 0.3.12

- **FIX**: only generate Flutter plugins files if workspace one exists.
- **FIX**: add default sdk constrain when no melos.yaml detected (fixes #32).
- **FIX**: trailing spaces in generated pubspec.lock file (fixes #36) (#38).
- **FIX**: re-word the help message of the --yes args in version command. (#33).
- **FEAT**: add "ignore" support on "melos.yaml" configuration (#37).
- **FEAT**: advanced custom script definitions (with package selection prompting) (#34).
- **FEAT**: version `--preid` support (#30).

## 0.3.11

- **FEAT**: Add `--yes` flag to `melos version` for ci support. (#27).
- **CHORE**: make `--yes` on `version` command non negatable.

## 0.3.10

- Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 0.3.10-dev.9

- **FIX**: use dummy yaml file.

## 0.3.10-dev.8

- **FIX**: correctly assign YamlList.

## 0.3.10-dev.7

- **FIX**: add default packages path.

## 0.3.10-dev.6

- **FIX**: melos.yaml check.

## 0.3.10-dev.5

- **FEAT**: allow melos to function without a yaml file if packages dir exists.

## 0.3.10-dev.4

- **FEAT**: support adding git tags for missing versions on publish command.

## 0.3.10-dev.3

- **REFACTOR**: break out conventional_commit package.
- **FEAT**: re-add bootstrap `bs` alias.
- **BUILD**: fix version.dart not being automatically added.

## 0.3.10-dev.2

- **REFACTOR**: remove logger, woops.
- **REFACTOR**: remove dep override.
- **FIX**: don't filter packages using 'since' on version command.
- **FEAT**: add support for version/postversion lifecycle scripts.
- **BUILD**: temporary git add workaround for additional changed files in melos.
- **BUILD**: add version lifecycle script to generate version.dart file.

## 0.3.10-dev.1

- **REFACTOR**: code cleanup.
- **REFACTOR**: remove committed .iml files.
- **FEAT**: semver & conventional commits (#10).
- **CHORE**: bump dep version.

## 0.3.9

- Fix version.dart versioning

## 0.3.8

- Move all generated pub files into a `.melos_tool` sub directory in workspace root to prevent conflicts.
- Clean up IntelliJ `runConfigurations` as part of the `clean` command.
- Prefix all IntelliJ generated project files with `melos_`.

## 0.3.7

- IntelliJ support for automatically generating Flutter Test & Run configurations.

## 0.3.6

- Fixed an issue on Windows where Pub Cache can also being the 'Roaming' AppData directory.

## 0.3.5

- Use `exitCode` setter instead of `exit()`.

## 0.3.0

- Added support for Windows.
- Added workspace support for IntelliJ IDEs (Android Studio).

## 0.2.0

- Added a new filter for filtering published or unpublished packages: `--[no-]published`.
    - Unpublished in this case means the package either does not exist on the Pub registry or the current local version
      of the package is not yet published to the Pub registry.
- Added a new command to pretty print currently unpublished packages: `melos unpublished`.
