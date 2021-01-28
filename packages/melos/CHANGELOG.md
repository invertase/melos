## 0.4.3

 - **FEAT**: add various new flags (#54).

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
 - **REFACTOR**: remove commited .iml files.
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

- Fixed an issue on Windows where Pub Cache can also being the the 'Roaming' AppData directory.

## 0.3.5

- Use `exitCode` setter instead of `exit()`.

## 0.3.0

- Added support for Windows.
- Added workspace support for IntelliJ IDEs (Android Studio).

## 0.2.0

- Added a new filter for filtering published or unpublished packages: `--[no-]published`.
  - Unpublished in this case means the package either does not exist on the Pub registry or the current local version of the package is not yet published to the Pub registry.
- Added a new command to pretty print currently unpublished packages: `melos unpublished`.

#### Example `--[no-]published` usage

Example logging out all unpublished packages and their versions:

```bash
mike@MikeMacMini fe_ff_master % melos exec --no-published --ignore="*example*" -- echo MELOS_PACKAGE_NAME MELOS_PACKAGE_VERSION
$ melos exec --no-published
   └> echo MELOS_PACKAGE_NAME MELOS_PACKAGE_VERSION
       └> RUNNING (in 12 packages)

[firebase_admob]: firebase_admob 0.9.3+4
[firebase_analytics_platform_interface]: firebase_analytics_platform_interface 1.0.3
[firebase_auth]: firebase_auth 0.17.0-dev.1
[firebase_auth_web]: firebase_auth_web 0.2.0-dev.1
[firebase_core]: firebase_core 0.5.0-dev.2
[firebase_crashlytics]: firebase_crashlytics 0.1.4+1
[firebase_database]: firebase_database 4.0.0-dev.1
[firebase_dynamic_links]: firebase_dynamic_links 0.5.3
[firebase_ml_vision]: firebase_ml_vision 0.9.5
[firebase_remote_config]: firebase_remote_config 0.3.1+1
[firebase_storage]: firebase_storage 4.0.0-dev.1

$ melos exec --no-published
   └> echo MELOS_PACKAGE_NAME MELOS_PACKAGE_VERSION
       └> SUCCESS
mike@MikeMacMini fe_ff_master %
```

#### Example `unpublished` usage

```bash
mike@MikeMacMini fe_ff_master % melos unpublished --ignore="*example*"
$ melos unpublished
   └> /Users/mike/Documents/Projects/Flutter/fe_ff_master

Reading registry for package information... SUCCESS

$ melos unpublished
   └> /Users/mike/Documents/Projects/Flutter/fe_ff_master
       └> UNPUBLISHED PACKAGES (12 packages)
           └> firebase_analytics_platform_interface
               • Local:   1.0.3
               • Remote:  1.0.1
           └> cloud_functions
               • Local:   0.6.0-dev.2
               • Remote:  0.6.0-dev.1
           └> firebase_core
               • Local:   0.5.0-dev.2
               • Remote:  0.5.0-dev.1
           └> firebase_auth_web
               • Local:   0.2.0-dev.1
               • Remote:  0.1.3+1
           └> firebase_dynamic_links
               • Local:   0.5.3
               • Remote:  0.5.1
           └> firebase_crashlytics
               • Local:   0.1.4+1
               • Remote:  0.1.3+3
           └> firebase_admob
               • Local:   0.9.3+4
               • Remote:  0.9.3+2
           └> firebase_ml_vision
               • Local:   0.9.5
               • Remote:  0.9.4
           └> firebase_remote_config
               • Local:   0.3.1+1
               • Remote:  0.3.1
           └> firebase_database
               • Local:   4.0.0-dev.1
               • Remote:  3.1.6
           └> firebase_auth
               • Local:   0.17.0-dev.1
               • Remote:  0.9.0
           └> firebase_storage
               • Local:   4.0.0-dev.1
               • Remote:  3.1.6

mike@MikeMacMini fe_ff_master %
```
