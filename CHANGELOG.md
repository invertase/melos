# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2022-01-07

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`conventional_commit` - `v0.4.2`](#conventional_commit---v042)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

- `melos` - `v1.1.2`

---

#### `conventional_commit` - `v0.4.2`

 - **FEAT**: relax commit message validation to accept commit messages without spaces before the description (after `:`).


## 2022-01-07

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`melos` - `v1.1.1`](#melos---v111)

---

#### `melos` - `v1.1.1`

 - **FIX**: ensure `.fvm` directories are excluded when resolving packages.
 - **DOCS**: add Flame to projects using Melos (#221).


## 2022-01-04

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`melos` - `v1.1.0`](#melos---v110)

---

#### `melos` - `v1.1.0`

 - **FEAT**: follow symlinks when resolving packages (#211).
 - **FEAT**: specifying a `Logger` is now optional when using Melos programmatically (#219).
 - **FEAT**: add repository host support for `GitLab` (#220).


## 2021-12-17

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`melos` - `v1.0.0`](#melos---v100)

Packages graduated to a stable release (see pre-releases prior to the stable version for changelog entries):

- `ansi_styles` - `v0.3.1`
- `conventional_commit` - `v0.4.1`

---

#### `melos` - `v1.0.0`

- **FIX**: a dependent packages `dependentsInWorkspace` dependents should also be added to `dependentPackagesToVersion`. ([5e7e8c75](https://github.com/invertase/melos/commit/5e7e8c756d4d0bebf403056aa863b88c502b69c2))
- **FIX**: ensure local versions of transitive dependencies are bootstrapped (#185).
- **FIX**: don't remove pubspec.lock when `clean` is ran (fixes #129).
- **FIX**: melos_tools path incorrect on certain platforms (fixes #144).
- **FEAT**: Match unknown commands with scripts (#167).
- **FEAT**: Added an error message when multiple packages in the workspace have the same name (#178).
- **FEAT**: verbose logging now logs package commit messages when versioning (#203). ([b87fb8dc](https://github.com/invertase/melos/commit/b87fb8dcf21d0aeb8524cd9212e21115829d5c0d))
- **FEAT**: optionally allow generating workspace root change logs (#161). ([56fcdff6](https://github.com/invertase/melos/commit/56fcdff6640f73a01c6d7e5f7fb453bf8ef5666e))
- **FEAT**: Add topological sort to publish command (#199).
- **FEAT**: use `dart` tool to run `pub get` in pure Dart package (#201).
- **FEAT**: respect exact version constraints when updating dependents (#194).
- **FEAT**: add support for linking to commits in changelog (#186).
- **FEAT**: add support for printing current Melos version via `-v` or `--version` (#155).
- **FEAT**: added config validation and type-safe Dart API (#139) (#140).
- **FEAT**: migrate Melos to null-safety (#115).
- **FEAT**: added "preversion" script hook, to perform actions when using `melos version` _before_ pubspec files are modified.
- **FEAT**: added `melos.yaml` validation
- **FEAT**: it is now possible to programmatically use Melos commands by importing `package:melos/melos.dart`:

```dart
final melos = Melos(workingDirectory: Directory.current);

await melos.bootstrap();
await melos.publish(dryRun: false);
```

## 2021-12-08

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`melos` - `v1.0.0-dev.14`](#melos---v100-dev14)

---

#### `melos` - `v1.0.0-dev.14`

- **FIX**: a dependent packages `dependentsInWorkspace` dependents should also be added to `dependentPackagesToVersion`.

## 2021-12-06

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`melos` - `v1.0.0-dev.13`](#melos---v100-dev13)

---

#### `melos` - `v1.0.0-dev.13`

- **FEAT**: verbose logging now logs package commit messages when versioning (#203).

## 2021-12-05

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`melos` - `v1.0.0-dev.12`](#melos---v100-dev12)

---

#### `melos` - `v1.0.0-dev.12`

- **FEAT**: optionally allow generating workspace root change logs (#161).
