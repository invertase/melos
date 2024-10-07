## 6.2.0

 - **FIX**: Propagate error code when fail fast is enabled ([#762](https://github.com/invertase/melos/issues/762)). ([ed6243bd](https://github.com/invertase/melos/commit/ed6243bd0882c61d82a79a35c95e1e1e9e874921))
 - **FIX**: Don't deadlock on cycle exec with order dependents ([#761](https://github.com/invertase/melos/issues/761)). ([cec45d7d](https://github.com/invertase/melos/commit/cec45d7d6f042b7a173ea520a813a94fe445cab7))
 - **FIX**: maintain working directory across script steps ([#711](https://github.com/invertase/melos/issues/711)). ([a3784c16](https://github.com/invertase/melos/commit/a3784c16bd6337b3baba1953b5e52cb33fa25f43))
 - **FIX**: Flaky tests when run in GitHub Actions Workflow ([#733](https://github.com/invertase/melos/issues/733)). ([4a67d098](https://github.com/invertase/melos/commit/4a67d098686b4724cae23d24bdab46be820aa0b3))
 - **FEAT**: Allow overriding `enforceLockfile` with `--no-enforce-lockfile` ([#758](https://github.com/invertase/melos/issues/758)). ([86647f1d](https://github.com/invertase/melos/commit/86647f1d2eea7ce66063fe44b0af70dc633a093e))
 - **FEAT**: Expose `pub get`'s `--offline` flag on the bootstrap command ([#756](https://github.com/invertase/melos/issues/756)). ([b432749c](https://github.com/invertase/melos/commit/b432749c3214bd106b0c67173740d6e23eca9e23))
 - **DOCS**: Add signals to list of projects using Melos ([#754](https://github.com/invertase/melos/issues/754)). ([dc05a52c](https://github.com/invertase/melos/commit/dc05a52c21796dd1c2455d0ddc2f2981b88e8d9c))
 - **DOCS**: Add PowerSync to list of projects using Melos ([#746](https://github.com/invertase/melos/issues/746)). ([24fbcec1](https://github.com/invertase/melos/commit/24fbcec134773d5a61ffaa07a8b84f4daf3bbe41))

## 6.1.0

 - **FIX**: `updateDependentsVersions` disabled with packages still mentioned in changelogs ([#719](https://github.com/invertase/melos/issues/719)). ([0ad8f585](https://github.com/invertase/melos/commit/0ad8f5851333bc5d197132f9e7ec7c0a8b1ca45a))
 - **FIX**: tryParse line-length to int when it's not already an integer ([#708](https://github.com/invertase/melos/issues/708)). ([35ef462d](https://github.com/invertase/melos/commit/35ef462d7e9621bfd05bd3a7825a20acee91a289))
 - **FEAT**: Filter by category ([#727](https://github.com/invertase/melos/issues/727)). ([71bc6104](https://github.com/invertase/melos/commit/71bc61043b74ccd5e7c529d7e7a055ff9be1b517))
 - **FEAT**: added Alice to readme ([#725](https://github.com/invertase/melos/issues/725)). ([7b7a10e0](https://github.com/invertase/melos/commit/7b7a10e0596dad8f6bce3ddf23e9a57c4751daf3))
 - **FEAT**: `changelogFormat` configuration, add `includeDate` boolean ([#720](https://github.com/invertase/melos/issues/720)). ([fed343b2](https://github.com/invertase/melos/commit/fed343b2dd58e9a30b29244c38f8ba815a104082))
 - **FEAT**: add config for the format command ([#709](https://github.com/invertase/melos/issues/709)). ([5a6ec6f7](https://github.com/invertase/melos/commit/5a6ec6f708fe27e2fa608698340d36adf3e854ac))

## 6.0.0

> Note: This release has breaking changes.

 - **FIX**: Only enforce lockfile when it exists ([#704](https://github.com/invertase/melos/issues/704)). ([be94adac](https://github.com/invertase/melos/commit/be94adacac71d8263079641229640932b387891a))
 - **FEAT**: option to provide dependencies related filters from yaml ([#698](https://github.com/invertase/melos/issues/698)). ([92be9858](https://github.com/invertase/melos/commit/92be9858cd64f35cce2d3a3ba2f4184cd32d0955))
 - **FEAT**: add `--line-length` option to `melos format` command ([#689](https://github.com/invertase/melos/issues/689)). ([048ab301](https://github.com/invertase/melos/commit/048ab301ca0f01f99d198c3ba6ca0f3c951078cf))
 - **DOCS**: fix misalignment in readme ([#699](https://github.com/invertase/melos/issues/699)). ([5e588ef9](https://github.com/invertase/melos/commit/5e588ef92d5e5ad25bb99be5a279305c4c07e9a9))
 - **BREAKING** **FIX**: Make `melos analyze` always use `dart analyze` ([#695](https://github.com/invertase/melos/issues/695)). ([2b16e360](https://github.com/invertase/melos/commit/2b16e3609bf3e00d15c42968dfbaeac2663a48c9))

## 5.3.0

 - **FIX**: melos analyze concurrency flag log output ([#678](https://github.com/invertase/melos/issues/678)). ([2ee575e4](https://github.com/invertase/melos/commit/2ee575e4f2087717d15600c4ab4228df1a7c1c30))
 - **FEAT**: support for melos command within script steps ([#683](https://github.com/invertase/melos/issues/683)). ([a1da197f](https://github.com/invertase/melos/commit/a1da197fb00dd9b174a30593533ae79e48bcbafe))
 - **FEAT**: add support for `melos bs --skip-linking` ([#684](https://github.com/invertase/melos/issues/684)). ([699fedc0](https://github.com/invertase/melos/commit/699fedc0cc0ba1b8d9b8a39638761f4ab1764b6a))
 - **FEAT**: add support for Azure DevOps repository ([#681](https://github.com/invertase/melos/issues/681)). ([16fc890d](https://github.com/invertase/melos/commit/16fc890d1d5ee40d47be6f9dfd565de927f1b32c))
 - **FEAT**: Change concurrent log to sequential log ([#679](https://github.com/invertase/melos/issues/679)). ([15b1518b](https://github.com/invertase/melos/commit/15b1518b2af185aa1c87fe60f1178844826c5091))

## 5.2.2

 - **FIX**: revisionRange not resolving to correct diff ([#674](https://github.com/invertase/melos/issues/674)). ([289a2f73](https://github.com/invertase/melos/commit/289a2f73101569a802064c758e9b2e4210349272))

## 5.2.1

 - **FIX**: exec command with failFast should fail immediately ([#665](https://github.com/invertase/melos/issues/665)). ([a5ff6da9](https://github.com/invertase/melos/commit/a5ff6da983130299a2170cb38b6bf1c19ac77cc9))
 - **FIX**: fix diff functionality ([#669](https://github.com/invertase/melos/issues/669)). ([08d6ec2a](https://github.com/invertase/melos/commit/08d6ec2a97df386e69b2fc4baa736f152f1f3ab8))

## 5.2.0

 - **FEAT**: add support for combining scripts ([#664](https://github.com/invertase/melos/issues/664)). ([aabf21c5](https://github.com/invertase/melos/commit/aabf21c5847f68b364098b9458bae053292795c8))

## 5.1.0

 - **FEAT**: format built in command ([#657](https://github.com/invertase/melos/issues/657)). ([e0491f54](https://github.com/invertase/melos/commit/e0491f5466f79ce56cd010f5970a783c34756480))

## 5.0.0

> Note: This release has breaking changes.

 - **REFACTOR**: Move `CommandConfigs` and `LifecycleHooks` to their own directories ([#652](https://github.com/invertase/melos/issues/652)). ([95f23716](https://github.com/invertase/melos/commit/95f23716b33152afb73a1b64a8302138fcbff6f7))
 - **REFACTOR**: move environment variable related strings into one class ([#648](https://github.com/invertase/melos/issues/648)). ([2db32ec5](https://github.com/invertase/melos/commit/2db32ec568e64440ee03a85321f2ba60457d7012))
 - **FIX**: use `git pull --tags` instead of `git fetch --tags` ([#468](https://github.com/invertase/melos/issues/468)). ([109f5f98](https://github.com/invertase/melos/commit/109f5f985dc65172f6392285cd0b239bd0b43fff))
 - **FIX**: typo on help description of bootstrap --enforce-lockfile ([#636](https://github.com/invertase/melos/issues/636)). ([a5247561](https://github.com/invertase/melos/commit/a5247561804a1a030325366bcd05c6a6a7a5c7dd))
 - **FEAT**: Add lifecycle hooks for `publish` ([#656](https://github.com/invertase/melos/issues/656)). ([ed826b39](https://github.com/invertase/melos/commit/ed826b39761039ba545d3ae7b18f491726d7ebe1))
 - **FEAT**: built-in melos command for analyzing projects ([#655](https://github.com/invertase/melos/issues/655)). ([93db45df](https://github.com/invertase/melos/commit/93db45dffc0f8b23d97e11d67a4b9cc7b4818737))
 - **FEAT**: Default to number of processors for exec concurrency ([#654](https://github.com/invertase/melos/issues/654)). ([43c6ddb7](https://github.com/invertase/melos/commit/43c6ddb72a89de1eed08193388996c9f9c15e1c2))
 - **DOCS**: add more projects using melos ([#649](https://github.com/invertase/melos/issues/649)). ([30611f40](https://github.com/invertase/melos/commit/30611f40e14f34fce178fffebd44fff83f10fa50))
 - **BREAKING** **FEAT**: make run script use melos_packages env variable scope ([#640](https://github.com/invertase/melos/issues/640)). ([e12ff57e](https://github.com/invertase/melos/commit/e12ff57efd71baae5eea20252d02894ec8be712e))

## 4.1.0

> Note: This release has breaking changes.

 - **FIX**: typo on help description of bootstrap --enforce-lockfile ([#636](https://github.com/invertase/melos/issues/636)). ([a5247561](https://github.com/invertase/melos/commit/a5247561804a1a030325366bcd05c6a6a7a5c7dd))
 - **BREAKING** **FEAT**: make run script use melos_packages env variable scope ([#640](https://github.com/invertase/melos/issues/640)). ([e12ff57e](https://github.com/invertase/melos/commit/e12ff57efd71baae5eea20252d02894ec8be712e))

## 4.0.0

 - **FIX**: Compare with correct version when publishing ([#633](https://github.com/invertase/melos/issues/633)). ([9c4cd2eb](https://github.com/invertase/melos/commit/9c4cd2eb470de79eaa026ce8449d559f0a161374))
 - **FIX**: Expose script api ([#573](https://github.com/invertase/melos/issues/573)). ([bb971018](https://github.com/invertase/melos/commit/bb9710185a735e7176646e509433f4c033a2c774))
 - **FEAT**: Add `git-commit-version` flag to control commit creation ([#628](https://github.com/invertase/melos/issues/628)). ([cca71872](https://github.com/invertase/melos/commit/cca7187233727aaf84bd83bf41bca11c5f962372))
 - **FEAT**: support authenticating private pub repository ([#627](https://github.com/invertase/melos/issues/627)). ([dddc7b31](https://github.com/invertase/melos/commit/dddc7b31b2bb2588c23efc6b5a43ce5acfab1329))
 - **FEAT**: Add enforce lockfile bootstrap command config ([#600](https://github.com/invertase/melos/issues/600)). ([b9c6d0cc](https://github.com/invertase/melos/commit/b9c6d0ccd55698d244dd856c26767e5e3a9852ac))
 - **FEAT**: add "--no-example" arg to "pub get " command for melos bootstrap ([#604](https://github.com/invertase/melos/issues/604)). ([8b69f51f](https://github.com/invertase/melos/commit/8b69f51fd71eec01ebeba7bf5e3f0a691feac986))
 - **DOCS**: Add flutter_web_auth_2 to melos project list ([#624](https://github.com/invertase/melos/issues/624)). ([bbede2d2](https://github.com/invertase/melos/commit/bbede2d2a795f37b5db2468c3e130278b09c7bea))
 - **BREAKING** **FIX**: Create commit when `--no-git-tag-version` is used ([#625](https://github.com/invertase/melos/issues/625)). ([b89133dc](https://github.com/invertase/melos/commit/b89133dc79e56920727451e409b3adc1d2e666ee))

### Migration instructions

If you were previously using `--no-git-tag-version` and were relying on that it
didn't create a commit you now have to also pass `--no-git-commit-version` to
prevent a commit from being automatically created after versioning.

## 3.4.0

 - **FEAT**: add support for bitbucket repository url ([#608](https://github.com/invertase/melos/issues/608)). ([6f3ea624](https://github.com/invertase/melos/commit/6f3ea62466547ecddf309a0a4d387ffdb3168a13))

## 3.3.0

 - **REFACTOR**: Remove unnecessary parenthesis to get analyzer green ([#602](https://github.com/invertase/melos/issues/602)). ([d368b439](https://github.com/invertase/melos/commit/d368b439941cb21a46f5f2681c70c5e438b301bf))
 - **FIX**: `.idea/modules.xml` should always uses `/` instead of `\` ([#582](https://github.com/invertase/melos/issues/582)). ([5d49c4a6](https://github.com/invertase/melos/commit/5d49c4a6c7d227a56935366e9bf1c9aaf5b61122))
 - **FEAT**: add option that allows to include commit bodies in changelog ([#606](https://github.com/invertase/melos/issues/606)). ([524e58a1](https://github.com/invertase/melos/commit/524e58a1d2c72d39b62e355997d06134c9342b53))
 - **DOCS**(melos): add `coverde` to projects using Melos ([#562](https://github.com/invertase/melos/issues/562)). ([6a64b059](https://github.com/invertase/melos/commit/6a64b0595d01003145049125226fa2db2c45c918))

## 3.2.0

 - **REFACTOR**: fix analyzer issues ([#590](https://github.com/invertase/melos/issues/590)). ([2f19770e](https://github.com/invertase/melos/commit/2f19770eee9deff097d26202bece72bd6b2127a1))
 - **FEAT**: support syncing common dependency versions ([#526](https://github.com/invertase/melos/issues/526)). ([39e5e499](https://github.com/invertase/melos/commit/39e5e499d71e95cf7794ae724ab2ccd3bb4e9fd5))
 - **FEAT**: Expose `Changelog` and `ManualVersionChange` ([#538](https://github.com/invertase/melos/issues/538)). ([b049ed89](https://github.com/invertase/melos/commit/b049ed897402921a5b0f3b818e49b47e3b3bf4cf))
 - **DOCS**: added link to `atproto.dart` ([#544](https://github.com/invertase/melos/issues/544)). ([aa891d82](https://github.com/invertase/melos/commit/aa891d8268f0aba7335ca274af747a15c9e72848))
 - **DOCS**: growerp also use melos ([#551](https://github.com/invertase/melos/issues/551)). ([c679622f](https://github.com/invertase/melos/commit/c679622f1279107e31ec1d10d2b21c18877f7771))

## 3.1.1

 - **FIX**: pass extra args to exec scripts ([#540](https://github.com/invertase/melos/issues/540)). ([27b2275d](https://github.com/invertase/melos/commit/27b2275d5f44cbc3b93e780c88618363afca0b55))
 - **FIX**: generate correct path in `modules.xml` for package at workspace root ([#539](https://github.com/invertase/melos/issues/539)). ([712ae6c3](https://github.com/invertase/melos/commit/712ae6c332d2f50e9b62917f4ffeb9debb1279cc))

## 3.1.0

 - **REFACTOR**: tidy up workspace name validation and fix docs ([#522](https://github.com/invertase/melos/issues/522)). ([3d76097d](https://github.com/invertase/melos/commit/3d76097db131b760368766ecbf7e133f2e1db23e))
 - **FEAT**: improve output for multi-line scripts ([#524](https://github.com/invertase/melos/issues/524)). ([b4d71300](https://github.com/invertase/melos/commit/b4d7130006d7cdc04967c6b42f41850f56f71229))
 - **FEAT**: set exit code to 1 when detecting cycles in `melos list` ([#523](https://github.com/invertase/melos/issues/523)). ([e2863e6f](https://github.com/invertase/melos/commit/e2863e6f043702da4d1b12d0ac837211beb8977e))
 - **DOCS**: add `NetGlade/auto_mappr` to user of melos ([#508](https://github.com/invertase/melos/issues/508)). ([60c86195](https://github.com/invertase/melos/commit/60c86195c176d1b06f0bd983d903593465a15ce7))

## 3.0.1

 - **DOCS**: pin docs to latest Melos release ([#373](https://github.com/invertase/melos/issues/373)). ([d1fd8d1f](https://github.com/invertase/melos/commit/d1fd8d1ff7f785fb625e34da65b2662bcabfbb60))

## 3.0.0

> Note: This release has breaking changes.

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
 - **FIX**: change used API endpoint for querying versions ([#486](https://github.com/invertase/melos/issues/486)). ([1a5c8547](https://github.com/invertase/melos/commit/1a5c8547fd1c41640a1f15ae79fe8303ead40eea))
 - **FEAT**: support listing cycles in dependencies ([#491](https://github.com/invertase/melos/issues/491)). ([6521ce0c](https://github.com/invertase/melos/commit/6521ce0cd3ea296532a782913647cb9e957d9302))
 - **DOCS**: add `mobx.dart` to projects using Melos ([#476](https://github.com/invertase/melos/issues/476)). ([be3fc431](https://github.com/invertase/melos/commit/be3fc4317a01b2b38db5489c8961c868e0ccfec8))


## 3.0.0-dev.1

 - **FIX**: change used API endpoint for querying versions ([#486](https://github.com/invertase/melos/issues/486)). ([1a5c8547](https://github.com/invertase/melos/commit/1a5c8547fd1c41640a1f15ae79fe8303ead40eea))
 - **FEAT**: support listing cycles in dependencies ([#491](https://github.com/invertase/melos/issues/491)). ([6521ce0c](https://github.com/invertase/melos/commit/6521ce0cd3ea296532a782913647cb9e957d9302))
 - **DOCS**: add `mobx.dart` to projects using Melos ([#476](https://github.com/invertase/melos/issues/476)). ([be3fc431](https://github.com/invertase/melos/commit/be3fc4317a01b2b38db5489c8961c868e0ccfec8))

## 3.0.0-dev.0

> Note: This release has breaking changes.

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

## 2.9.0

 - **FIX**: support bootstrapping Flutter example packages ([#428](https://github.com/invertase/melos/issues/428)). ([53873682](https://github.com/invertase/melos/commit/538736827f4fdcd2ec0b2d2b33168a8d1397a319))
 - **FEAT**: implement scoped changelogs ([#421](https://github.com/invertase/melos/issues/421)). ([f0eca8db](https://github.com/invertase/melos/commit/f0eca8dbd06831256733d5bf38cfe171ac1ca30d))
 - **FEAT**: support self-hosted git repositories ([#417](https://github.com/invertase/melos/issues/417)). ([ce6e4efc](https://github.com/invertase/melos/commit/ce6e4efcff062c19e8bd35ef2cf7976a53aaae4c))

## 2.8.0

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

## 2.7.1

 - **REFACTOR**: move over versioning logic from `conventional_commit`. ([75a6fda0](https://github.com/invertase/melos/commit/75a6fda09e2afdcea07d091e6cb48a2cbd2b7fac))
 - **DOCS**: document versioning ([#377](https://github.com/invertase/melos/issues/377)). ([cc64f1f4](https://github.com/invertase/melos/commit/cc64f1f48c032a60f1d58057df8e08f517c76d33))

## 2.7.0

 - **REFACTOR**: fix a few analyzer issues ([#365](https://github.com/invertase/melos/issues/365)). ([74adb062](https://github.com/invertase/melos/commit/74adb062650687a9b7bc8c108a96fbfbb71d023a))
 - **FIX**: handle prompts when no terminal is attached to stdio ([#370](https://github.com/invertase/melos/issues/370)). ([81e850e9](https://github.com/invertase/melos/commit/81e850e9d380e8474f76b813eafd887e50dddcd5))
 - **FIX**: run commands in single shell ([#369](https://github.com/invertase/melos/issues/369)). ([1ab2e290](https://github.com/invertase/melos/commit/1ab2e2902aedda02aed8a6bc009703bf1b8c01e3))
 - **FIX**: `scripts.*.exec.failFast` option in `melos.yaml` ([#359](https://github.com/invertase/melos/issues/359)). ([16fe6916](https://github.com/invertase/melos/commit/16fe691665466e81e34c87451e8b1ca32809bf95))
 - **FEAT**: Add support for specifying an IntelliJ module name prefix ([#349](https://github.com/invertase/melos/issues/349)). ([1d2720fa](https://github.com/invertase/melos/commit/1d2720fa7e73fc07766d0a9acd621fdb7f7fb311))

## 2.6.0

 - **REFACTOR**: use `homepage` and `repository` keys in `pubspec.yaml` ([#354](https://github.com/invertase/melos/issues/354)). ([c7a78e3a](https://github.com/invertase/melos/commit/c7a78e3af1ebc3d3a0d2973fdbe154813b8eb2e3))
 - **REFACTOR**: enable more lint rules ([#346](https://github.com/invertase/melos/issues/346)). ([70448bec](https://github.com/invertase/melos/commit/70448bec7d8cf5f8d0a8dc8c2660e70033936329))
 - **REFACTOR**: remove local fork of `yamlicious` ([#345](https://github.com/invertase/melos/issues/345)). ([64a15b83](https://github.com/invertase/melos/commit/64a15b83f87d9c21c0bcad10f4e6d4941f935091))
 - **REFACTOR**: remove local fork of `prompts` package ([#344](https://github.com/invertase/melos/issues/344)). ([200450c3](https://github.com/invertase/melos/commit/200450c3064ae461dafc1eebee285c762a28eba1))
 - **FIX**: don't override Intellij module config files ([#351](https://github.com/invertase/melos/issues/351)). ([850e9f82](https://github.com/invertase/melos/commit/850e9f8227ff3233b3f348260ec16ff05b13991d))
 - **FIX**: false positive for non-unique packages ([#348](https://github.com/invertase/melos/issues/348)). ([9c136194](https://github.com/invertase/melos/commit/9c136194ac888be5f6b6ccc0543ea369507ba129))
 - **FEAT**: write conventional commit scopes in changelog ([#341](https://github.com/invertase/melos/issues/341)). ([0c64d61e](https://github.com/invertase/melos/commit/0c64d61eb9fa0f65b85a21e0843e112d0b717733))
 - **DOCS**: update link to the FlutterFire repository ([#338](https://github.com/invertase/melos/issues/338)). ([344df53c](https://github.com/invertase/melos/commit/344df53c2bd8bd8e331708013e336fed9e820b81))

## 2.5.0

 - **FIX**: follow up [#330](https://github.com/invertase/melos/issues/330) ([#331](https://github.com/invertase/melos/issues/331)). ([f6eec0a2](https://github.com/invertase/melos/commit/f6eec0a295c186715a68ee5b6ee96f32de2184e9))
 - **FIX**: find packages in matched directories ([#330](https://github.com/invertase/melos/issues/330)). ([c7be5235](https://github.com/invertase/melos/commit/c7be523517155ab0a4221e3bf95474cd2cea17a3))
 - **FIX**: make file IO more robust ([#329](https://github.com/invertase/melos/issues/329)). ([dfd877d6](https://github.com/invertase/melos/commit/dfd877d62b607cf5c2c482c5a9719e4d5523606a))
 - **FIX**: handle `UsageException` ([#328](https://github.com/invertase/melos/issues/328)). ([c187f9d9](https://github.com/invertase/melos/commit/c187f9d99197d3549b3da9b9612509317f03171a))
 - **FEAT**: add `runPubGetOffline` option ([#326](https://github.com/invertase/melos/issues/326)). ([8358a5a1](https://github.com/invertase/melos/commit/8358a5a11b55a81e1a01b31fe1931f7ba88c07e0))
 - **FEAT**: add includeCommitId option ([#325](https://github.com/invertase/melos/issues/325)). ([e981adf7](https://github.com/invertase/melos/commit/e981adf72f2a53181f184239f592781c728616cb))
 - **FEAT**: add --diff filter ([#323](https://github.com/invertase/melos/issues/323)). ([2f6545f6](https://github.com/invertase/melos/commit/2f6545f658a2eabc50ab7c68f47326588d6eeb2c))

## 2.4.0

 - **REFACTOR**: encapsulate log formatting in `MelosLogger` ([#314](https://github.com/invertase/melos/issues/314)). ([ec808b02](https://github.com/invertase/melos/commit/ec808b0205cb267f3c8bedd8dce98a02f9f6a086))
 - **FIX**: pass extra args to script when invoked without `run` ([#316](https://github.com/invertase/melos/issues/316)). ([f0a62a2d](https://github.com/invertase/melos/commit/f0a62a2d124b4b8e29534c16daaff88a49f69442))
 - **FIX**: report all dependencies in `list` command ([#313](https://github.com/invertase/melos/issues/313)). ([bb76d3a1](https://github.com/invertase/melos/commit/bb76d3a126794df05d0c823f6f8aae0311761ae1))
 - **FIX**: respect user `dependency_overrides` ([#312](https://github.com/invertase/melos/issues/312)). ([ff5bfbe6](https://github.com/invertase/melos/commit/ff5bfbe6a43f3a1a788832951c1873d150a28d7d))
 - **FIX**: Run Process.runSync in another shell to get Dart version ([#300](https://github.com/invertase/melos/issues/300)). ([0aa81a7b](https://github.com/invertase/melos/commit/0aa81a7bbad0d635981ffd52d323fe80dff97458))
 - **FEAT**: simplify writing scripts that use `melos exec` ([#315](https://github.com/invertase/melos/issues/315)). ([3e5807dd](https://github.com/invertase/melos/commit/3e5807ddde999479c6d9937a131dd0919ad7dae8))

## 2.3.1

 - **FIX**: use global options when running scripts ([#296](https://github.com/invertase/melos/issues/296)). ([115d0471](https://github.com/invertase/melos/commit/115d04710028612686eba3cb669f93704cac5893))

## 2.3.0

 - **FIX**: respect filter flags in `melos bootstrap` ([#294](https://github.com/invertase/melos/issues/294)). ([c87287e0](https://github.com/invertase/melos/commit/c87287e00d27036b9860a33e26f06c0b3bfef76f))
 - **FEAT**: link to referenced issues/PRs in changelog ([#292](https://github.com/invertase/melos/issues/292)). ([1883020b](https://github.com/invertase/melos/commit/1883020b77829122ed368998752f0196d328c60d))
 - **FEAT**: remove dependency overrides from `pubspec_overrides.yaml` in `melos clean` ([#290](https://github.com/invertase/melos/issues/290)). ([869b2d69](https://github.com/invertase/melos/commit/869b2d695b0c00061b2de2c2c325acd48bdf5208))
 - **DOCS**: use `dart pub` instead of `pub` in `README.md` ([#293](https://github.com/invertase/melos/issues/293)). ([d6beb1c3](https://github.com/invertase/melos/commit/d6beb1c33a7b4512bfcbaeaa1b0b9985e2ac3fb5))

## 2.2.0

 - **FEAT**: add support for Dart/Flutter SDK at custom `sdkPath` (#288). ([740050c4](https://github.com/invertase/melos/commit/740050c4dd67938d0674ddd37f0291d52f331bd4))

## 2.1.0

 - **FEAT**: start to log `pub get` output if it runs for more than 10s (#286). ([fca44a48](https://github.com/invertase/melos/commit/fca44a480a3de9b888bde52abf184307f99b7476))
 - **FEAT**: add `command/bootstrap/runPubGetInParallel` `melos.yaml` option (#285). ([f48e8f14](https://github.com/invertase/melos/commit/f48e8f14f781b2fbc5663854808dd0f86a291f03))

## 2.0.0

 - **PERF**: run `pub get` in parallel during bootstrapping (#279). ([9870270d](https://github.com/invertase/melos/commit/9870270dbe7a6b5834110aeae0e49d79ca3b8c42))
 - **FIX**: handle unresolvable symbolic links (#280). ([70094363](https://github.com/invertase/melos/commit/700943631a84a88270a99f3baf6dcb2843c584d1))
 - **DOCS**: added WiFiFlutter as proj using melos (#281). ([2c900ee8](https://github.com/invertase/melos/commit/2c900ee853ec865529950f4eaa3b5ef606b684cf))
 - **FIX**: `melos bootstrap` now correctly handles path dependencies (#268). ([96457b59](https://github.com/invertase/melos/commit/96457b59c00feed97e4204fcea24706c1510a8fb))
 - **FEAT**: allow checking melos version (`melos --version`) outside of workspaces & set up autoupdater (#276). ([c3dc28f7](https://github.com/invertase/melos/commit/c3dc28f7832561e175ff0097c21bacef9501a4d3))
 - **BREAKING** **REFACTOR**: remove `--all` flag from list command & show private packages by default (you can use the `--no-private` filter flag instead to hide private packages) (#275). ([921ec4e4](https://github.com/invertase/melos/commit/921ec4e4de7e87a19a6017f87d4691f99f8c7f32))
 - **FEAT**: add support for bootstrapping with pubspec overrides (#273). ([236e24f4](https://github.com/invertase/melos/commit/236e24f4ef36d088b18f716ae4b030d9c514ca25))

## 1.6.0-dev.2

 - **PERF**: run `pub get` in parallel during bootstrapping (#279). ([9870270d](https://github.com/invertase/melos/commit/9870270dbe7a6b5834110aeae0e49d79ca3b8c42))
 - **FIX**: handle unresolvable symbolic links (#280). ([70094363](https://github.com/invertase/melos/commit/700943631a84a88270a99f3baf6dcb2843c584d1))
 - **DOCS**: added WiFiFlutter as proj using melos (#281). ([2c900ee8](https://github.com/invertase/melos/commit/2c900ee853ec865529950f4eaa3b5ef606b684cf))

## 1.6.0-dev.1

> Note: This release has breaking changes.

 - **FIX**: `melos bootstrap` now correctly handles path dependencies (#268). ([96457b59](https://github.com/invertase/melos/commit/96457b59c00feed97e4204fcea24706c1510a8fb))
 - **FEAT**: allow checking melos version (`melos --version`) outside of workspaces & set up autoupdater (#276). ([c3dc28f7](https://github.com/invertase/melos/commit/c3dc28f7832561e175ff0097c21bacef9501a4d3))
 - **BREAKING** **REFACTOR**: remove `--all` flag from list command & show private packages by default (you can use the `--no-private` filter flag instead to hide private packages) (#275). ([921ec4e4](https://github.com/invertase/melos/commit/921ec4e4de7e87a19a6017f87d4691f99f8c7f32))

## 1.6.0-dev.0

 - **FEAT**: add support for bootstrapping with pubspec overrides (#273). ([236e24f4](https://github.com/invertase/melos/commit/236e24f4ef36d088b18f716ae4b030d9c514ca25))

## 1.5.2

 - **FIX**: hosted dependency version regex (#262). ([b6e1bf4e](https://github.com/invertase/melos/commit/b6e1bf4e5c07ff78bb572bf864edd3023d6e4249))

## 1.5.1

 - **FIX**: support external hosted dependencies (#254). ([0f904f36](https://github.com/invertase/melos/commit/0f904f3630342188162714ac06b6cac99e925552))

## 1.5.0

 - **FIX**: export `MelosConfigException` for programatic usage. ([8b7fbfb5](https://github.com/invertase/melos/commit/8b7fbfb55ea223c11da370e4b2b3feb57c347f20))
 - **FEAT**: support git hosted package dependencies when versioning (#256). ([c76c08f3](https://github.com/invertase/melos/commit/c76c08f3660ae7679a4ab7631d633ba05e36e608))
 - **FEAT**: get published package versions from `pubspec.yaml` -> `publish_to` if set, instead of pub.dev (#253). ([9a5cb26e](https://github.com/invertase/melos/commit/9a5cb26e19a8de3d2a13ea460ba5864005e4e9b4))

## 1.4.0

 - **FIX**: don't use `Enum.name` (#251). ([27dcc7ad](https://github.com/invertase/melos/commit/27dcc7ad9f40876b682cbb783717bd08a4b485d4))
 - **FEAT**: add flag to show relative paths when using `list` (FR #246) (#257). ([06be8a14](https://github.com/invertase/melos/commit/06be8a1435abd7860b24b3be34706a83bd9d1ae5))

## 1.3.0

 - **FEAT**: add `--manual-version` option to `version` command (#242). ([279c53e4](https://github.com/invertase/melos/commit/279c53e44c735c1ef2339d1c73f097e820a72251))

## 1.2.2

- **FIX**: fully consume `pub get` output when bootstrapping (#240). ([09e98a5e](https://github.com/invertase/melos/commit/09e98a5e6197db661cdf4f89deeff5020aa3b417))

## 1.2.1

 - **FIX**: bump `platform` dependency to to 3.1.0 to support latest Flutter/Dart versions (#237). ([2b74f6eb](https://github.com/invertase/melos/commit/2b74f6ebe1852d36b65cfe0e4a8e8d6cd78fe939))

## 1.2.0

 - **FIX**: Issue where symlinks are followed too deeply causing a "File name too long" exception (#227). ([80332f32](https://github.com/invertase/melos/commit/80332f322421e586c66badda5b2b5aaf5006dc0a))
 - **FEAT**: allow passing additional arguments to run commands (#231). ([cbae75c7](https://github.com/invertase/melos/commit/cbae75c762b4cff55f47c002800119218d827f76))
 - **DOCS**: add groveman as a project using melos (#225). ([4bff84ff](https://github.com/invertase/melos/commit/4bff84ffc83387ba9ed43ce786af179e234c7188))

## 1.1.2

 - Update a dependency to the latest release.

## 1.1.1

 - **FIX**: ensure `.fvm` directories are excluded when resolving packages. ([06bad5bf](https://github.com/invertase/melos/commit/06bad5bf764f6904ff24f3b51b23a9c5961de6dd))
 - **DOCS**: add Flame to projects using Melos (#221). ([abc6b4d6](https://github.com/invertase/melos/commit/abc6b4d6adb114023e9c8415e8acb91fc82efd25))

## 1.1.0

 - **FEAT**: follow symlinks when resolving packages (#211). ([f8551924](https://github.com/invertase/melos/commit/f8551924b78d5c1f5ff9cd49cdc1c8ef1e78757f))
 - **FEAT**: specifying a `Logger` is now optional when using Melos programmatically (#219). ([67dbfc5b](https://github.com/invertase/melos/commit/67dbfc5bbf6ffdc9bf230a7733b3389082f65091))
 - **FEAT**: add repository host support for `GitLab` (#220). ([096d1713](https://github.com/invertase/melos/commit/096d1713ac964e5e8685bc9f115e174f4a57e7c5))

## 1.0.0

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

## 1.0.0-dev.14

- **FIX**: a dependent packages `dependentsInWorkspace` dependents should also be added to `dependentPackagesToVersion`. ([5e7e8c75](https://github.com/invertase/melos/commit/5e7e8c756d4d0bebf403056aa863b88c502b69c2))

## 1.0.0-dev.13

- **FEAT**: verbose logging now logs package commit messages when versioning (#203). ([b87fb8dc](https://github.com/invertase/melos/commit/b87fb8dcf21d0aeb8524cd9212e21115829d5c0d))

## 1.0.0-dev.12

- **FEAT**: optionally allow generating workspace root change logs (#161). ([56fcdff6](https://github.com/invertase/melos/commit/56fcdff6640f73a01c6d7e5f7fb453bf8ef5666e))

## 1.0.0-dev.11

- **FEAT**: Add topological sort to publish command (#199).
- **FEAT**: use `dart` tool to run `pub get` in pure Dart package (#201).
- **DOCS**: fix a few things and expand page for `melos.yaml` (#200).

## 1.0.0-dev.10

- **FIX**: run version cmd with `--dependent-versions` value from cli (#193).
- **FEAT**: respect exact version constraints when updating dependents (#194).

## 1.0.0-dev.9

- **FIX**: melos.yaml ignores should apply also to `run` commands `MELOS_PACKAGES` env variable (#192).

## 1.0.0-dev.8

- **FIX**: version `--graduate` should graduate prerelease packages (not the other way around).

## 1.0.0-dev.7

- **FIX**: ignore package filter should merge with `config.ignore` globs.

## 1.0.0-dev.6

- **FEAT**: add support for linking to commits in changelog (#186).

## 1.0.0-dev.5

- **FIX**: prevent stack overflow when resolving transitively related packages (#187).

## 1.0.0-dev.4

- **REFACTOR**: Pass workspace config from the top (#176).
- **REFACTOR**: fix analysis & formatting issues (#177).
- **REFACTOR**: Instantiate workspace from configs (#169).
- **FIX**: ensure local versions of transitive dependencies are bootstrapped (#185).
- **FEAT**: Match unknown commands with scripts (#167).
- **FEAT**: Added an error message when multiple packages in the workspace have the same name (#178).

## 1.0.0-dev.3

- **FIX**: Allow add-to-app packages to bootstrap (#162).

## 1.0.0-dev.2

- **FIX**: fix cast error (#151).
- **FEAT**: add support for printing current melos version via `-v` or `--version` (#155).
- **CHORE**: fix lints on master channel (#147).

## 1.0.0-dev.1

- **REFACTOR**: misc cleanup of todos.
- **FIX**: issue where all environment variables are injected into exec scripts instead of just `MELOS_*` ones (fixes #146).
- **FIX**: manual versioning should run lifecycle scripts.
- **FIX**: don't remove pubspec.lock when `clean` is ran (fixes #129).
- **CHORE**: bump "melos" to `1.0.0-dev.0`.

## 1.0.0-dev.0

- Bump "melos" to `1.0.0-dev.0`.

## 0.5.0-dev.2

- **FIX**: unable to publish packages (always dry-run).

## 0.5.0-dev.1

- **REFACTOR**: use currentPlatform instead of Platform.
- **FIX**: melos_tools path incorrect on certain platforms (fixes #144).

## 0.5.0-dev.0

> Note: This release has potentially breaking changes.

- **TEST**: add git tests.
- **REFACTOR**: cleanup git utilities and add new utils for upstream checks.
- **REFACTOR**: set Melos as the generator for generated pub files (#120).
- **FIX**: issue where dependent packages were not versioned (#131).
- **FIX**: enable Dart SDK for root IntelliJ project (#127).
- **FIX**: exec hang, exec trailing options (#123).
- **FEAT**: added config validation and type-safe Dart API (#139) (#140).
- **FEAT**: migrate Melos to null-safety (#115).
- **BREAKING** **FEAT**: migrate conventional_commit to null-safety (#114).
- added "preversion" script hook, to perform actions when using `melos version` _before_ pubspec files are modified.
- added `melos.yaml` validation
- it is now possible to programatically use melos commands by importing `package:melos/melos.dart`:

```dart
final melos = Melos(workingDirectory: Directory.current);

await melos.bootstrap();
await melos.publish(dryRun: false);
```

## 0.4.11+2

- **FIX**: pubspecs incorrectly being overwritten (fixes #60) (#110).

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
