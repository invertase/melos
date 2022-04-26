# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2022-04-26

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v2.0.0`](#melos---v200)

---

#### `melos` - `v2.0.0`

 - Bump "melos" to `2.0.0`.


## 2022-04-26

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v1.6.0-dev.2`](#melos---v160-dev2)

---

#### `melos` - `v1.6.0-dev.2`

 - **PERF**: run `pub get` in parallel during bootstrapping (#279). ([9870270d](https://github.com/invertase/melos/commit/9870270dbe7a6b5834110aeae0e49d79ca3b8c42))
 - **FIX**: handle unresolvable symbolic links (#280). ([70094363](https://github.com/invertase/melos/commit/700943631a84a88270a99f3baf6dcb2843c584d1))
 - **DOCS**: added WiFiFlutter as proj using melos (#281). ([2c900ee8](https://github.com/invertase/melos/commit/2c900ee853ec865529950f4eaa3b5ef606b684cf))


## 2022-04-12

### Changes

---

Packages with breaking changes:

 - [`melos` - `v1.6.0-dev.1`](#melos---v160-dev1)

Packages with other changes:

 - There are no other changes in this release.

---

#### `melos` - `v1.6.0-dev.1`

 - **FIX**: `melos bootstrap` now correctly handles path dependencies (#268). ([96457b59](https://github.com/invertase/melos/commit/96457b59c00feed97e4204fcea24706c1510a8fb))
 - **FEAT**: allow checking melos version (`melos --version`) outside of workspaces & set up autoupdater (#276). ([c3dc28f7](https://github.com/invertase/melos/commit/c3dc28f7832561e175ff0097c21bacef9501a4d3))
 - **BREAKING** **REFACTOR**: remove `--all` flag from list command & show private packages by default (you can use the `--no-private` filter flag instead to hide private packages) (#275). ([921ec4e4](https://github.com/invertase/melos/commit/921ec4e4de7e87a19a6017f87d4691f99f8c7f32))


## 2022-04-11

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v1.6.0-dev.0`](#melos---v160-dev0)

---

#### `melos` - `v1.6.0-dev.0`

 - **FEAT**: add support for bootstrapping with pubspec overrides (#273). ([236e24f4](https://github.com/invertase/melos/commit/236e24f4ef36d088b18f716ae4b030d9c514ca25))


## 2022-03-22

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v1.5.2`](#melos---v152)

---

#### `melos` - `v1.5.2`

 - **FIX**: hosted dependency version regex (#262). ([b6e1bf4e](https://github.com/invertase/melos/commit/b6e1bf4e5c07ff78bb572bf864edd3023d6e4249))


## 2022-03-21

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v1.5.1`](#melos---v151)

---

#### `melos` - `v1.5.1`

 - **FIX**: support external hosted dependencies (#254). ([0f904f36](https://github.com/invertase/melos/commit/0f904f3630342188162714ac06b6cac99e925552))


## 2022-03-18

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`conventional_commit` - `v0.4.3`](#conventional_commit---v043)
 - [`melos` - `v1.5.0`](#melos---v150)

---

#### `conventional_commit` - `v0.4.3`

 - **FEAT**: allow prefixes before conventional commit type (#259). ([e856cfa5](https://github.com/invertase/melos/commit/e856cfa59f3a3c2b5bd753d2be0a1a0a512822a0))

#### `melos` - `v1.5.0`

 - **FIX**: export `MelosConfigException` for programatic usage. ([8b7fbfb5](https://github.com/invertase/melos/commit/8b7fbfb55ea223c11da370e4b2b3feb57c347f20))
 - **FEAT**: support git hosted package dependencies when versioning (#256). ([c76c08f3](https://github.com/invertase/melos/commit/c76c08f3660ae7679a4ab7631d633ba05e36e608))
 - **FEAT**: get published package versions from `pubspec.yaml` -> `publish_to` if set, instead of pub.dev (#253). ([9a5cb26e](https://github.com/invertase/melos/commit/9a5cb26e19a8de3d2a13ea460ba5864005e4e9b4))


## 2022-03-04

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v1.4.0`](#melos---v140)

---

#### `melos` - `v1.4.0`

 - **FIX**: don't use `Enum.name` (#251). ([27dcc7ad](https://github.com/invertase/melos/commit/27dcc7ad9f40876b682cbb783717bd08a4b485d4))
 - **FEAT**: add flag to show relative paths when using `list` (FR #246) (#257). ([06be8a14](https://github.com/invertase/melos/commit/06be8a1435abd7860b24b3be34706a83bd9d1ae5))


## 2022-02-10

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v1.3.0`](#melos---v130)

---

#### `melos` - `v1.3.0`

 - **FEAT**: add `--manual-version` option to `version` command (#242). ([279c53e4](https://github.com/invertase/melos/commit/279c53e44c735c1ef2339d1c73f097e820a72251))


## 2022-02-09

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`melos` - `v1.2.2`](#melos---v122)

---

#### `melos` - `v1.2.2`

 - **FIX**: fully consume `pub get` output when bootstrapping (#240).


## 2022-02-04

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`melos` - `v1.2.1`](#melos---v121)

---

#### `melos` - `v1.2.1`

 - **FIX**: bump `platform` dependency to to 3.1.0 to support latest Flutter/Dart versions (#237).


## 2022-01-26

### Changes

---

Packages with breaking changes:

- There are no breaking changes in this release.

Packages with other changes:

- [`melos` - `v1.2.0`](#melos---v120)

---

#### `melos` - `v1.2.0`

 - **FIX**: Issue where symlinks are followed too deeply causing a "File name too long" exception (#227).
 - **FEAT**: allow passing additional arguments to run commands (#231).
 - **DOCS**: add groveman as a project using melos (#225).


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
