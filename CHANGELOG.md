# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2024-02-06

### Changes

---

Packages with breaking changes:

 - [`melos` - `v4.1.0`](#melos---v410)

Packages with other changes:

 - There are no other changes in this release.

---

#### `melos` - `v4.1.0`

 - **FIX**: typo on help description of bootstrap --enforce-lockfile ([#636](https://github.com/invertase/melos/issues/636)). ([a5247561](https://github.com/invertase/melos/commit/a5247561804a1a030325366bcd05c6a6a7a5c7dd))
 - **BREAKING** **FEAT**: make run script use melos_packages env variable scope ([#640](https://github.com/invertase/melos/issues/640)). ([e12ff57e](https://github.com/invertase/melos/commit/e12ff57efd71baae5eea20252d02894ec8be712e))


## 2024-01-11

### Changes

---

Packages with breaking changes:

 - [`melos` - `v4.0.0`](#melos---v400)

---

#### `melos` - `v4.0.0`

 - **FIX**: Compare with correct version when publishing ([#633](https://github.com/invertase/melos/issues/633)). ([9c4cd2eb](https://github.com/invertase/melos/commit/9c4cd2eb470de79eaa026ce8449d559f0a161374))
 - **FIX**: Expose script api ([#573](https://github.com/invertase/melos/issues/573)). ([bb971018](https://github.com/invertase/melos/commit/bb9710185a735e7176646e509433f4c033a2c774))
 - **FEAT**: Add `git-commit-version` flag to control commit creation ([#628](https://github.com/invertase/melos/issues/628)). ([cca71872](https://github.com/invertase/melos/commit/cca7187233727aaf84bd83bf41bca11c5f962372))
 - **FEAT**: support authenticating private pub repository ([#627](https://github.com/invertase/melos/issues/627)). ([dddc7b31](https://github.com/invertase/melos/commit/dddc7b31b2bb2588c23efc6b5a43ce5acfab1329))
 - **FEAT**: Add enforce lockfile bootstrap command config ([#600](https://github.com/invertase/melos/issues/600)). ([b9c6d0cc](https://github.com/invertase/melos/commit/b9c6d0ccd55698d244dd856c26767e5e3a9852ac))
 - **FEAT**: add "--no-example" arg to "pub get " command for melos bootstrap ([#604](https://github.com/invertase/melos/issues/604)). ([8b69f51f](https://github.com/invertase/melos/commit/8b69f51fd71eec01ebeba7bf5e3f0a691feac986))
 - **DOCS**: Add flutter_web_auth_2 to melos project list ([#624](https://github.com/invertase/melos/issues/624)). ([bbede2d2](https://github.com/invertase/melos/commit/bbede2d2a795f37b5db2468c3e130278b09c7bea))
 - **BREAKING** **FIX**: Create commit when `--no-git-tag-version` is used ([#625](https://github.com/invertase/melos/issues/625)). ([b89133dc](https://github.com/invertase/melos/commit/b89133dc79e56920727451e409b3adc1d2e666ee))


## 2023-12-04

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v3.4.0`](#melos---v340)

---

#### `melos` - `v3.4.0`

 - **FEAT**: add support for bitbucket repository url ([#608](https://github.com/invertase/melos/issues/608)). ([6f3ea624](https://github.com/invertase/melos/commit/6f3ea62466547ecddf309a0a4d387ffdb3168a13))


## 2023-12-01

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v3.3.0`](#melos---v330)

---

#### `melos` - `v3.3.0`

 - **REFACTOR**: Remove unnecessary parenthesis to get analyzer green ([#602](https://github.com/invertase/melos/issues/602)). ([d368b439](https://github.com/invertase/melos/commit/d368b439941cb21a46f5f2681c70c5e438b301bf))
 - **FIX**: `.idea/modules.xml` should always uses `/` instead of `\` ([#582](https://github.com/invertase/melos/issues/582)). ([5d49c4a6](https://github.com/invertase/melos/commit/5d49c4a6c7d227a56935366e9bf1c9aaf5b61122))
 - **FEAT**: add option that allows to include commit bodies in changelog ([#606](https://github.com/invertase/melos/issues/606)). ([524e58a1](https://github.com/invertase/melos/commit/524e58a1d2c72d39b62e355997d06134c9342b53))
 - **DOCS**(melos): add `coverde` to projects using Melos ([#562](https://github.com/invertase/melos/issues/562)). ([6a64b059](https://github.com/invertase/melos/commit/6a64b0595d01003145049125226fa2db2c45c918))


## 2023-10-24

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v3.2.0`](#melos---v320)

---

#### `melos` - `v3.2.0`

 - **REFACTOR**: fix analyzer issues ([#590](https://github.com/invertase/melos/issues/590)). ([2f19770e](https://github.com/invertase/melos/commit/2f19770eee9deff097d26202bece72bd6b2127a1))
 - **FEAT**: support syncing common dependency versions ([#526](https://github.com/invertase/melos/issues/526)). ([39e5e499](https://github.com/invertase/melos/commit/39e5e499d71e95cf7794ae724ab2ccd3bb4e9fd5))
 - **FEAT**: Expose `Changelog` and `ManualVersionChange` ([#538](https://github.com/invertase/melos/issues/538)). ([b049ed89](https://github.com/invertase/melos/commit/b049ed897402921a5b0f3b818e49b47e3b3bf4cf))
 - **DOCS**: added link to `atproto.dart` ([#544](https://github.com/invertase/melos/issues/544)). ([aa891d82](https://github.com/invertase/melos/commit/aa891d8268f0aba7335ca274af747a15c9e72848))
 - **DOCS**: growerp also use melos ([#551](https://github.com/invertase/melos/issues/551)). ([c679622f](https://github.com/invertase/melos/commit/c679622f1279107e31ec1d10d2b21c18877f7771))


## 2023-07-14

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v3.1.1`](#melos---v311)

---

#### `melos` - `v3.1.1`

 - **FIX**: pass extra args to exec scripts ([#540](https://github.com/invertase/melos/issues/540)). ([27b2275d](https://github.com/invertase/melos/commit/27b2275d5f44cbc3b93e780c88618363afca0b55))
 - **FIX**: generate correct path in `modules.xml` for package at workspace root ([#539](https://github.com/invertase/melos/issues/539)). ([712ae6c3](https://github.com/invertase/melos/commit/712ae6c332d2f50e9b62917f4ffeb9debb1279cc))


## 2023-05-22

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v3.1.0`](#melos---v310)

---

#### `melos` - `v3.1.0`

 - **REFACTOR**: tidy up workspace name validation and fix docs ([#522](https://github.com/invertase/melos/issues/522)). ([3d76097d](https://github.com/invertase/melos/commit/3d76097db131b760368766ecbf7e133f2e1db23e))
 - **FEAT**: improve output for multi-line scripts ([#524](https://github.com/invertase/melos/issues/524)). ([b4d71300](https://github.com/invertase/melos/commit/b4d7130006d7cdc04967c6b42f41850f56f71229))
 - **FEAT**: set exit code to 1 when detecting cycles in `melos list` ([#523](https://github.com/invertase/melos/issues/523)). ([e2863e6f](https://github.com/invertase/melos/commit/e2863e6f043702da4d1b12d0ac837211beb8977e))
 - **DOCS**: add `NetGlade/auto_mappr` to user of melos ([#508](https://github.com/invertase/melos/issues/508)). ([60c86195](https://github.com/invertase/melos/commit/60c86195c176d1b06f0bd983d903593465a15ce7))


## 2023-03-30

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`conventional_commit` - `v0.6.0+1`](#conventional_commit---v0601)
 - [`melos` - `v3.0.1`](#melos---v301)

---

#### `conventional_commit` - `v0.6.0+1`

 - **FIX**: commit scopes that contain "-" should be treated as valid scopes ([#496](https://github.com/invertase/melos/issues/496)). ([615c208e](https://github.com/invertase/melos/commit/615c208e08bb6c7a4c159fe0a06561b0b42edd50))

#### `melos` - `v3.0.1`

 - **DOCS**: pin docs to latest Melos release ([#373](https://github.com/invertase/melos/issues/373)). ([d1fd8d1f](https://github.com/invertase/melos/commit/d1fd8d1ff7f785fb625e34da65b2662bcabfbb60))


## 2023-03-10

### Changes

---

Packages with breaking changes:

 - [`melos` - `v3.0.0`](#melos---v300)

Packages with other changes:

 - [`conventional_commit` - `v0.6.0`](#conventional_commit---v060)

Packages graduated to a stable release:

 - `conventional_commit` - `v0.6.0`
 - `melos` - `v3.0.0`

---

#### `melos` - `v3.0.0`

 - **FIX**: change used API endpoint for querying versions ([#486](https://github.com/invertase/melos/issues/486)). ([1a5c8547](https://github.com/invertase/melos/commit/1a5c8547fd1c41640a1f15ae79fe8303ead40eea))
 - **FEAT**: support listing cycles in dependencies ([#491](https://github.com/invertase/melos/issues/491)). ([6521ce0c](https://github.com/invertase/melos/commit/6521ce0cd3ea296532a782913647cb9e957d9302))
 - **DOCS**: add `mobx.dart` to projects using Melos ([#476](https://github.com/invertase/melos/issues/476)). ([be3fc431](https://github.com/invertase/melos/commit/be3fc4317a01b2b38db5489c8961c868e0ccfec8))
 - **PERF**: use `Glob.list` to more efficiently find packages ([#426](https://github.com/invertase/melos/issues/426)). ([d7a85417](https://github.com/invertase/melos/commit/d7a854177d775b18dc123a69f0749d8fd1ed749e))
 - **FIX**: only stage `CHANGELOG.md` when package version changes ([#459](https://github.com/invertase/melos/issues/459)). ([a3e9bdc4](https://github.com/invertase/melos/commit/a3e9bdc4374c4796298e1be6516dbfb2883f0470))
 - **FIX**: updateGitTagRefs not working for versions like 0.1.2+3 ([#456](https://github.com/invertase/melos/issues/456)). ([2a4f5ff9](https://github.com/invertase/melos/commit/2a4f5ff9e1e63487d21682310750a6fa669c5924))
 - **FIX**: validate prerelease format is supported ([#449](https://github.com/invertase/melos/issues/449)). ([4504c659](https://github.com/invertase/melos/commit/4504c65958d0561c3e43f069f1fd546a7a6d3cd0))
 - **FEAT**: improve error message for when no workspace can be found ([#465](https://github.com/invertase/melos/issues/465)). ([60b39c96](https://github.com/invertase/melos/commit/60b39c960dba2cb78526f9a69e825b2702ae084c))
 - **FEAT**: fetch tags before versioning ([#461](https://github.com/invertase/melos/issues/461)). ([3088b7bc](https://github.com/invertase/melos/commit/3088b7bc7c23bbe277488bc3b655132545b17cd9))
 - **FEAT**: support running scripts in topological order with `melos exec` ([#440](https://github.com/invertase/melos/issues/440)). ([efe608b8](https://github.com/invertase/melos/commit/efe608b84e90b0ad95524a6a7b0e5c0e00deeb17))
 - **FEAT**: validate "melos exec" is not used in "run" along with "exec" ([#438](https://github.com/invertase/melos/issues/438)). ([628f798e](https://github.com/invertase/melos/commit/628f798e95c42ffbc1df2931301b40856e30410a))
 - **FEAT**: add path to `IOException` message ([#436](https://github.com/invertase/melos/issues/436)). ([f8e1551d](https://github.com/invertase/melos/commit/f8e1551d4df98783748df180233bec612b17bbd5))
 - **FEAT**: add support for `melos_overrides.yaml` + `command/bootstrap/dependencyOverridePaths` ([#410](https://github.com/invertase/melos/issues/410)). ([bf26b52f](https://github.com/invertase/melos/commit/bf26b52f695cd906885004bf67373242e8c06b94))
 - **DOCS**: take advantage of new `docs.page` features ([#464](https://github.com/invertase/melos/issues/464)). ([e5a2b42e](https://github.com/invertase/melos/commit/e5a2b42e6ade646cd8d403f409823f642aaed955))
 - **BREAKING** **FEAT**: move lifecycle hooks to command sections ([#466](https://github.com/invertase/melos/issues/466)). ([29cdf5ca](https://github.com/invertase/melos/commit/29cdf5ca3ea55fa2be1f5faefdf1e37c1824f88e))
 - **BREAKING** **FEAT**: local installation of melos in workspace ([#431](https://github.com/invertase/melos/issues/431)). ([9b080a5d](https://github.com/invertase/melos/commit/9b080a5d509daf7d6baaa28c2eb40ba12e235fd3))
 - **BREAKING** **FEAT**: make naming around package filters more consistent ([#462](https://github.com/invertase/melos/issues/462)). ([d71e749a](https://github.com/invertase/melos/commit/d71e749a73d4da0c665fb2a12d2497bfd0965a8a))
 - **BREAKING** **FEAT**: revise lifecycle hooks ([#458](https://github.com/invertase/melos/issues/458)). ([a1a265ec](https://github.com/invertase/melos/commit/a1a265ececef8c128539d61c14dc04d7f1efdd1d))
 - **BREAKING** **FEAT**: enable more options by default ([#457](https://github.com/invertase/melos/issues/457)). ([dc2c9fcc](https://github.com/invertase/melos/commit/dc2c9fcc06dcf305e0c4dc6f5bad46cc2ad67f6d))
 - **BREAKING** **FEAT**: remove `--since` filter in favour of `--diff` ([#454](https://github.com/invertase/melos/issues/454)). ([a5c53040](https://github.com/invertase/melos/commit/a5c530400970e1f96e56a34e5a70121f845232a3))
 - **BREAKING** **FEAT**: only support bootstrapping with `pubspec_overrides.yaml` ([#430](https://github.com/invertase/melos/issues/430)). ([973aac84](https://github.com/invertase/melos/commit/973aac84452244d27e672e282fb611609b19c968))
 - **BREAKING** **FEAT**: upgrade minimum Dart SDK version to 2.18.0 ([#429](https://github.com/invertase/melos/issues/429)). ([fa81cba0](https://github.com/invertase/melos/commit/fa81cba00960ef04702d1535f57cb644ffcaeaae))

#### `conventional_commit` - `v0.6.0`

 - **BREAKING** **FEAT**: upgrade minimum Dart SDK version to 2.18.0 ([#429](https://github.com/invertase/melos/issues/429)). ([fa81cba0](https://github.com/invertase/melos/commit/fa81cba00960ef04702d1535f57cb644ffcaeaae))

## 2023-02-07

### Changes

---

Packages with breaking changes:

 - [`conventional_commit` - `v0.6.0-dev.0`](#conventional_commit---v060-dev0)
 - [`melos` - `v3.0.0-dev.0`](#melos---v300-dev0)

Packages with other changes:

 - There are no other changes in this release.

---

#### `conventional_commit` - `v0.6.0-dev.0`

 - **BREAKING** **FEAT**: upgrade minimum Dart SDK version to 2.18.0 ([#429](https://github.com/invertase/melos/issues/429)). ([fa81cba0](https://github.com/invertase/melos/commit/fa81cba00960ef04702d1535f57cb644ffcaeaae))

#### `melos` - `v3.0.0-dev.0`

 - **PERF**: use `Glob.list` to more efficiently find packages ([#426](https://github.com/invertase/melos/issues/426)). ([d7a85417](https://github.com/invertase/melos/commit/d7a854177d775b18dc123a69f0749d8fd1ed749e))
 - **FIX**: only stage `CHANGELOG.md` when package version changes ([#459](https://github.com/invertase/melos/issues/459)). ([a3e9bdc4](https://github.com/invertase/melos/commit/a3e9bdc4374c4796298e1be6516dbfb2883f0470))
 - **FIX**: updateGitTagRefs not working for versions like 0.1.2+3 ([#456](https://github.com/invertase/melos/issues/456)). ([2a4f5ff9](https://github.com/invertase/melos/commit/2a4f5ff9e1e63487d21682310750a6fa669c5924))
 - **FIX**: validate prerelease format is supported ([#449](https://github.com/invertase/melos/issues/449)). ([4504c659](https://github.com/invertase/melos/commit/4504c65958d0561c3e43f069f1fd546a7a6d3cd0))
 - **FEAT**: improve error message for when no workspace can be found ([#465](https://github.com/invertase/melos/issues/465)). ([60b39c96](https://github.com/invertase/melos/commit/60b39c960dba2cb78526f9a69e825b2702ae084c))
 - **FEAT**: fetch tags before versioning ([#461](https://github.com/invertase/melos/issues/461)). ([3088b7bc](https://github.com/invertase/melos/commit/3088b7bc7c23bbe277488bc3b655132545b17cd9))
 - **FEAT**: support running scripts in topological order with `melos exec` ([#440](https://github.com/invertase/melos/issues/440)). ([efe608b8](https://github.com/invertase/melos/commit/efe608b84e90b0ad95524a6a7b0e5c0e00deeb17))
 - **FEAT**: validate "melos exec" is not used in "run" along with "exec" ([#438](https://github.com/invertase/melos/issues/438)). ([628f798e](https://github.com/invertase/melos/commit/628f798e95c42ffbc1df2931301b40856e30410a))
 - **FEAT**: add path to `IOException` message ([#436](https://github.com/invertase/melos/issues/436)). ([f8e1551d](https://github.com/invertase/melos/commit/f8e1551d4df98783748df180233bec612b17bbd5))
 - **FEAT**: add support for `melos_overrides.yaml` + `command/bootstrap/dependencyOverridePaths` ([#410](https://github.com/invertase/melos/issues/410)). ([bf26b52f](https://github.com/invertase/melos/commit/bf26b52f695cd906885004bf67373242e8c06b94))
 - **DOCS**: take advantage of new `docs.page` features ([#464](https://github.com/invertase/melos/issues/464)). ([e5a2b42e](https://github.com/invertase/melos/commit/e5a2b42e6ade646cd8d403f409823f642aaed955))
 - **BREAKING** **FEAT**: move lifecycle hooks to command sections ([#466](https://github.com/invertase/melos/issues/466)). ([29cdf5ca](https://github.com/invertase/melos/commit/29cdf5ca3ea55fa2be1f5faefdf1e37c1824f88e))
 - **BREAKING** **FEAT**: local installation of melos in workspace ([#431](https://github.com/invertase/melos/issues/431)). ([9b080a5d](https://github.com/invertase/melos/commit/9b080a5d509daf7d6baaa28c2eb40ba12e235fd3))
 - **BREAKING** **FEAT**: make naming around package filters more consistent ([#462](https://github.com/invertase/melos/issues/462)). ([d71e749a](https://github.com/invertase/melos/commit/d71e749a73d4da0c665fb2a12d2497bfd0965a8a))
 - **BREAKING** **FEAT**: revise lifecycle hooks ([#458](https://github.com/invertase/melos/issues/458)). ([a1a265ec](https://github.com/invertase/melos/commit/a1a265ececef8c128539d61c14dc04d7f1efdd1d))
 - **BREAKING** **FEAT**: enable more options by default ([#457](https://github.com/invertase/melos/issues/457)). ([dc2c9fcc](https://github.com/invertase/melos/commit/dc2c9fcc06dcf305e0c4dc6f5bad46cc2ad67f6d))
 - **BREAKING** **FEAT**: remove `--since` filter in favour of `--diff` ([#454](https://github.com/invertase/melos/issues/454)). ([a5c53040](https://github.com/invertase/melos/commit/a5c530400970e1f96e56a34e5a70121f845232a3))
 - **BREAKING** **FEAT**: only support bootstrapping with `pubspec_overrides.yaml` ([#430](https://github.com/invertase/melos/issues/430)). ([973aac84](https://github.com/invertase/melos/commit/973aac84452244d27e672e282fb611609b19c968))
 - **BREAKING** **FEAT**: upgrade minimum Dart SDK version to 2.18.0 ([#429](https://github.com/invertase/melos/issues/429)). ([fa81cba0](https://github.com/invertase/melos/commit/fa81cba00960ef04702d1535f57cb644ffcaeaae))


## 2022-12-05

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v2.9.0`](#melos---v290)

---

#### `melos` - `v2.9.0`

 - **FIX**: support bootstrapping Flutter example packages ([#428](https://github.com/invertase/melos/issues/428)). ([53873682](https://github.com/invertase/melos/commit/538736827f4fdcd2ec0b2d2b33168a8d1397a319))
 - **FEAT**: implement scoped changelogs ([#421](https://github.com/invertase/melos/issues/421)). ([f0eca8db](https://github.com/invertase/melos/commit/f0eca8dbd06831256733d5bf38cfe171ac1ca30d))
 - **FEAT**: support self-hosted git repositories ([#417](https://github.com/invertase/melos/issues/417)). ([ce6e4efc](https://github.com/invertase/melos/commit/ce6e4efcff062c19e8bd35ef2cf7976a53aaae4c))


## 2022-10-28

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`conventional_commit` - `v0.5.0+1`](#conventional_commit---v0501)
 - [`melos` - `v2.8.0`](#melos---v280)

---

#### `conventional_commit` - `v0.5.0+1`

 - **FIX**: Merge commits should be versioned ([#407](https://github.com/invertase/melos/issues/407)). ([01d4cd0d](https://github.com/invertase/melos/commit/01d4cd0d01e87fa836d0bb92949a8ccccb8f8027))

#### `melos` - `v2.8.0`

 - **FIX**: Merge commits should be versioned ([#407](https://github.com/invertase/melos/issues/407)). ([01d4cd0d](https://github.com/invertase/melos/commit/01d4cd0d01e87fa836d0bb92949a8ccccb8f8027))
 - **FIX**: unicode characters in commit titles ([#412](https://github.com/invertase/melos/issues/412)). ([bb6563af](https://github.com/invertase/melos/commit/bb6563af62336bf32d45f1da38246336aad38690))
 - **FIX**: don't try to get published versions of private package ([#404](https://github.com/invertase/melos/issues/404)). ([9ea87a32](https://github.com/invertase/melos/commit/9ea87a3252ee07592f145bd2212b1015fd714168))
 - **FIX**: only include normal dependencies of transitive dependencies ([#387](https://github.com/invertase/melos/issues/387)). ([e0659e97](https://github.com/invertase/melos/commit/e0659e976ad2d9eef90f611fa012a51e14880657))
 - **FIX**: return type of `promptChoice` ([#391](https://github.com/invertase/melos/issues/391)). ([54004993](https://github.com/invertase/melos/commit/54004993c980a204533980508bb2c03b27fe45fc))
 - **FEAT**: output URLs to prefilled GitHub release forms when executing `melos version` ([#406](https://github.com/invertase/melos/issues/406)). ([9c22cfbe](https://github.com/invertase/melos/commit/9c22cfbeab87fb91c8f2ba20c81d199af4232177))
 - **FEAT**: allow help to be shown from anywhere ([#405](https://github.com/invertase/melos/issues/405)). ([d754055e](https://github.com/invertase/melos/commit/d754055e9da4cfbd6ea8fb860c1f175f9ddb1ca5))
 - **FEAT**: add `--dependent-preid` option ([#388](https://github.com/invertase/melos/issues/388)). ([b6201364](https://github.com/invertase/melos/commit/b6201364dd951db39ab422b6baaa812cef8b83fd))
 - **DOCS**: add `youtube_video` to projects using Melos ([#395](https://github.com/invertase/melos/issues/395)). ([2a8de822](https://github.com/invertase/melos/commit/2a8de82210a4b531243bfca8acb3c67a8e25c8bd))
 - **DOCS**: Add Converter NOW to projects that are using melos ([#408](https://github.com/invertase/melos/issues/408)). ([ddf5655c](https://github.com/invertase/melos/commit/ddf5655cd4c919724f9f8900932ecacba255b049))
 - **DOCS**: add `flutter_html` to projects using Melos ([#389](https://github.com/invertase/melos/issues/389)). ([4e3a4447](https://github.com/invertase/melos/commit/4e3a4447b41973eb4b779b096a0dbdfcf2a3188c))
 - **DOCS**: add yak_packages reference to docs/index ([#381](https://github.com/invertase/melos/issues/381)). ([9b366fd9](https://github.com/invertase/melos/commit/9b366fd917792dbdde1ed59a51beefd46bb88c57))


## 2022-09-23

### Changes

---

Packages with breaking changes:

 - [`conventional_commit` - `v0.5.0`](#conventional_commit---v050)

Packages with other changes:

 - [`melos` - `v2.7.1`](#melos---v271)

---

#### `conventional_commit` - `v0.5.0`

 - **BREAKING** **FEAT**: allow custom type. ([e55edb54](https://github.com/invertase/melos/commit/e55edb54ed2bfc8cb1e2e9205831930c35ce47d8))

#### `melos` - `v2.7.1`

 - **REFACTOR**: move over versioning logic from `conventional_commit`. ([75a6fda0](https://github.com/invertase/melos/commit/75a6fda09e2afdcea07d091e6cb48a2cbd2b7fac))
 - **DOCS**: document versioning ([#377](https://github.com/invertase/melos/issues/377)). ([cc64f1f4](https://github.com/invertase/melos/commit/cc64f1f48c032a60f1d58057df8e08f517c76d33))


## 2022-09-13

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v2.7.0`](#melos---v270)

---

#### `melos` - `v2.7.0`

 - **REFACTOR**: fix a few analyzer issues ([#365](https://github.com/invertase/melos/issues/365)). ([74adb062](https://github.com/invertase/melos/commit/74adb062650687a9b7bc8c108a96fbfbb71d023a))
 - **FIX**: handle prompts when no terminal is attached to stdio ([#370](https://github.com/invertase/melos/issues/370)). ([81e850e9](https://github.com/invertase/melos/commit/81e850e9d380e8474f76b813eafd887e50dddcd5))
 - **FIX**: run commands in single shell ([#369](https://github.com/invertase/melos/issues/369)). ([1ab2e290](https://github.com/invertase/melos/commit/1ab2e2902aedda02aed8a6bc009703bf1b8c01e3))
 - **FIX**: `scripts.*.exec.failFast` option in `melos.yaml` ([#359](https://github.com/invertase/melos/issues/359)). ([16fe6916](https://github.com/invertase/melos/commit/16fe691665466e81e34c87451e8b1ca32809bf95))
 - **FEAT**: Add support for specifying an IntelliJ module name prefix ([#349](https://github.com/invertase/melos/issues/349)). ([1d2720fa](https://github.com/invertase/melos/commit/1d2720fa7e73fc07766d0a9acd621fdb7f7fb311))


## 2022-07-18

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`conventional_commit` - `v0.4.3+1`](#conventional_commit---v0431)
 - [`melos` - `v2.6.0`](#melos---v260)

---

#### `conventional_commit` - `v0.4.3+1`

 - **REFACTOR**: enable more lint rules ([#346](https://github.com/invertase/melos/issues/346)). ([70448bec](https://github.com/invertase/melos/commit/70448bec7d8cf5f8d0a8dc8c2660e70033936329))

#### `melos` - `v2.6.0`

 - **REFACTOR**: use `homepage` and `repository` keys in `pubspec.yaml` ([#354](https://github.com/invertase/melos/issues/354)). ([c7a78e3a](https://github.com/invertase/melos/commit/c7a78e3af1ebc3d3a0d2973fdbe154813b8eb2e3))
 - **REFACTOR**: enable more lint rules ([#346](https://github.com/invertase/melos/issues/346)). ([70448bec](https://github.com/invertase/melos/commit/70448bec7d8cf5f8d0a8dc8c2660e70033936329))
 - **REFACTOR**: remove local fork of `yamlicious` ([#345](https://github.com/invertase/melos/issues/345)). ([64a15b83](https://github.com/invertase/melos/commit/64a15b83f87d9c21c0bcad10f4e6d4941f935091))
 - **REFACTOR**: remove local fork of `prompts` package ([#344](https://github.com/invertase/melos/issues/344)). ([200450c3](https://github.com/invertase/melos/commit/200450c3064ae461dafc1eebee285c762a28eba1))
 - **FIX**: don't override Intellij module config files ([#351](https://github.com/invertase/melos/issues/351)). ([850e9f82](https://github.com/invertase/melos/commit/850e9f8227ff3233b3f348260ec16ff05b13991d))
 - **FIX**: false positive for non-unique packages ([#348](https://github.com/invertase/melos/issues/348)). ([9c136194](https://github.com/invertase/melos/commit/9c136194ac888be5f6b6ccc0543ea369507ba129))
 - **FEAT**: write conventional commit scopes in changelog ([#341](https://github.com/invertase/melos/issues/341)). ([0c64d61e](https://github.com/invertase/melos/commit/0c64d61eb9fa0f65b85a21e0843e112d0b717733))
 - **DOCS**: update link to the FlutterFire repository ([#338](https://github.com/invertase/melos/issues/338)). ([344df53c](https://github.com/invertase/melos/commit/344df53c2bd8bd8e331708013e336fed9e820b81))


## 2022-06-21

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v2.5.0`](#melos---v250)

---

#### `melos` - `v2.5.0`

 - **FIX**: follow up [#330](https://github.com/invertase/melos/issues/330) ([#331](https://github.com/invertase/melos/issues/331)). ([f6eec0a2](https://github.com/invertase/melos/commit/f6eec0a295c186715a68ee5b6ee96f32de2184e9))
 - **FIX**: find packages in matched directories ([#330](https://github.com/invertase/melos/issues/330)). ([c7be5235](https://github.com/invertase/melos/commit/c7be523517155ab0a4221e3bf95474cd2cea17a3))
 - **FIX**: make file IO more robust ([#329](https://github.com/invertase/melos/issues/329)). ([dfd877d6](https://github.com/invertase/melos/commit/dfd877d62b607cf5c2c482c5a9719e4d5523606a))
 - **FIX**: handle `UsageException` ([#328](https://github.com/invertase/melos/issues/328)). ([c187f9d9](https://github.com/invertase/melos/commit/c187f9d99197d3549b3da9b9612509317f03171a))
 - **FEAT**: add `runPubGetOffline` option ([#326](https://github.com/invertase/melos/issues/326)). ([8358a5a1](https://github.com/invertase/melos/commit/8358a5a11b55a81e1a01b31fe1931f7ba88c07e0))
 - **FEAT**: add includeCommitId option ([#325](https://github.com/invertase/melos/issues/325)). ([e981adf7](https://github.com/invertase/melos/commit/e981adf72f2a53181f184239f592781c728616cb))
 - **FEAT**: add --diff filter ([#323](https://github.com/invertase/melos/issues/323)). ([2f6545f6](https://github.com/invertase/melos/commit/2f6545f658a2eabc50ab7c68f47326588d6eeb2c))


## 2022-06-10

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v2.4.0`](#melos---v240)

---

#### `melos` - `v2.4.0`

 - **REFACTOR**: encapsulate log formatting in `MelosLogger` ([#314](https://github.com/invertase/melos/issues/314)). ([ec808b02](https://github.com/invertase/melos/commit/ec808b0205cb267f3c8bedd8dce98a02f9f6a086))
 - **FIX**: pass extra args to script when invoked without `run` ([#316](https://github.com/invertase/melos/issues/316)). ([f0a62a2d](https://github.com/invertase/melos/commit/f0a62a2d124b4b8e29534c16daaff88a49f69442))
 - **FIX**: report all dependencies in `list` command ([#313](https://github.com/invertase/melos/issues/313)). ([bb76d3a1](https://github.com/invertase/melos/commit/bb76d3a126794df05d0c823f6f8aae0311761ae1))
 - **FIX**: respect user `dependency_overrides` ([#312](https://github.com/invertase/melos/issues/312)). ([ff5bfbe6](https://github.com/invertase/melos/commit/ff5bfbe6a43f3a1a788832951c1873d150a28d7d))
 - **FIX**: Run Process.runSync in another shell to get Dart version ([#300](https://github.com/invertase/melos/issues/300)). ([0aa81a7b](https://github.com/invertase/melos/commit/0aa81a7bbad0d635981ffd52d323fe80dff97458))
 - **FEAT**: simplify writing scripts that use `melos exec` ([#315](https://github.com/invertase/melos/issues/315)). ([3e5807dd](https://github.com/invertase/melos/commit/3e5807ddde999479c6d9937a131dd0919ad7dae8))


## 2022-05-16

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v2.3.1`](#melos---v231)

---

#### `melos` - `v2.3.1`

 - **FIX**: use global options when running scripts ([#296](https://github.com/invertase/melos/issues/296)). ([115d0471](https://github.com/invertase/melos/commit/115d04710028612686eba3cb669f93704cac5893))


## 2022-05-12

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v2.3.0`](#melos---v230)

---

#### `melos` - `v2.3.0`

 - **FIX**: respect filter flags in `melos bootstrap` ([#294](https://github.com/invertase/melos/issues/294)). ([c87287e0](https://github.com/invertase/melos/commit/c87287e00d27036b9860a33e26f06c0b3bfef76f))
 - **FEAT**: link to referenced issues/PRs in changelog ([#292](https://github.com/invertase/melos/issues/292)). ([1883020b](https://github.com/invertase/melos/commit/1883020b77829122ed368998752f0196d328c60d))
 - **FEAT**: remove dependency overrides from `pubspec_overrides.yaml` in `melos clean` ([#290](https://github.com/invertase/melos/issues/290)). ([869b2d69](https://github.com/invertase/melos/commit/869b2d695b0c00061b2de2c2c325acd48bdf5208))
 - **DOCS**: use `dart pub` instead of `pub` in `README.md` ([#293](https://github.com/invertase/melos/issues/293)). ([d6beb1c3](https://github.com/invertase/melos/commit/d6beb1c33a7b4512bfcbaeaa1b0b9985e2ac3fb5))


## 2022-05-09

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v2.2.0`](#melos---v220)

---

#### `melos` - `v2.2.0`

 - **FEAT**: add support for Dart/Flutter SDK at custom `sdkPath` (#288). ([740050c4](https://github.com/invertase/melos/commit/740050c4dd67938d0674ddd37f0291d52f331bd4))


## 2022-04-28

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`melos` - `v2.1.0`](#melos---v210)

---

#### `melos` - `v2.1.0`

 - **FEAT**: start to log `pub get` output if it runs for more than 10s (#286). ([fca44a48](https://github.com/invertase/melos/commit/fca44a480a3de9b888bde52abf184307f99b7476))
 - **FEAT**: add `command/bootstrap/runPubGetInParallel` `melos.yaml` option (#285). ([f48e8f14](https://github.com/invertase/melos/commit/f48e8f14f781b2fbc5663854808dd0f86a291f03))


## 2022-04-26

### Changes

---

Packages with breaking changes:

 - [`melos` - `v2.0.0`](#melos---v200)

---

#### `melos` - `v2.0.0`

 - **PERF**: run `pub get` in parallel during bootstrapping (#279). ([9870270d](https://github.com/invertase/melos/commit/9870270dbe7a6b5834110aeae0e49d79ca3b8c42))
 - **FIX**: handle unresolvable symbolic links (#280). ([70094363](https://github.com/invertase/melos/commit/700943631a84a88270a99f3baf6dcb2843c584d1))
 - **DOCS**: added WiFiFlutter as proj using melos (#281). ([2c900ee8](https://github.com/invertase/melos/commit/2c900ee853ec865529950f4eaa3b5ef606b684cf))
 - **FIX**: `melos bootstrap` now correctly handles path dependencies (#268). ([96457b59](https://github.com/invertase/melos/commit/96457b59c00feed97e4204fcea24706c1510a8fb))
 - **FEAT**: allow checking melos version (`melos --version`) outside of workspaces & set up autoupdater (#276). ([c3dc28f7](https://github.com/invertase/melos/commit/c3dc28f7832561e175ff0097c21bacef9501a4d3))
 - **BREAKING** **REFACTOR**: remove `--all` flag from list command & show private packages by default (you can use the `--no-private` filter flag instead to hide private packages) (#275). ([921ec4e4](https://github.com/invertase/melos/commit/921ec4e4de7e87a19a6017f87d4691f99f8c7f32))
 - **FEAT**: add support for bootstrapping with pubspec overrides (#273). ([236e24f4](https://github.com/invertase/melos/commit/236e24f4ef36d088b18f716ae4b030d9c514ca25))

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
