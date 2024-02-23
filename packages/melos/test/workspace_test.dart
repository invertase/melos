/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:convert';
import 'dart:io';
import 'dart:io' as io;

import 'package:melos/melos.dart';
import 'package:melos/src/common/environment_variable_key.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/common/utils.dart';
import 'package:melos/src/workspace.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';
import 'package:pubspec/pubspec.dart';
import 'package:test/test.dart';

import 'matchers.dart';
import 'mock_env.dart';
import 'mock_fs.dart';
import 'mock_workspace_fs.dart';
import 'utils.dart';

void main() {
  group('Workspace', () {
    test('throws if multiple packages have the same name', () async {
      final workspaceDir = await createTemporaryWorkspace();

      await createProject(
        workspaceDir,
        const PubSpec(name: 'a'),
      );
      await createProject(
        workspaceDir,
        const PubSpec(name: 'example'),
        path: 'packages/a/example',
      );
      await createProject(
        workspaceDir,
        const PubSpec(name: 'b'),
      );
      await createProject(
        workspaceDir,
        const PubSpec(name: 'example'),
        path: 'packages/b/example',
      );

      await expectLater(
        () async => MelosWorkspace.fromConfig(
          await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir),
          logger: TestLogger().toMelosLogger(),
        ),
        throwsMelosConfigException(
          message: anyOf(
            '''
Multiple packages with the name `example` found in the workspace, which is unsupported.
To fix this problem, consider renaming your packages to have a unique name.

The packages that caused the problem are:
- example at packages/a/example
- example at packages/b/example
''',
            '''
Multiple packages with the name `example` found in the workspace, which is unsupported.
To fix this problem, consider renaming your packages to have a unique name.

The packages that caused the problem are:
- example at packages/b/example
- example at packages/a/example
''',
          ),
        ),
      );
    });

    test('can be accessed from anywhere within a workspace', () async {
      final workspaceDir = await createTemporaryWorkspace(
        runPubGet: true,
        configBuilder: (path) => MelosWorkspaceConfig.fromYaml(
          path: path,
          const {
            'name': 'test',
            'packages': ['packages/*'],
          },
        ),
      );
      final projectDir =
          await createProject(workspaceDir, const PubSpec(name: 'a'));

      final result = await Process.run(
        'melos',
        ['list'],
        runInShell: io.Platform.isWindows,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
        workingDirectory: projectDir.path,
      );

      expect(result.exitCode, 0);
      expect(result.stdout, 'a\n');
    });

    test(
      'does not include projects inside packages/whatever/.dart_tool when no melos.yaml is specified',
      withMockFs(() async {
        // regression test for https://github.com/invertase/melos/issues/101

        final mockWorkspaceRootDir = createMockWorkspaceFs(
          workspaceRoot: '/root',
          packages: [
            MockPackageFs(name: 'a'),
            MockPackageFs(name: 'b', path: '/root/packages/a/.dart_tool/b'),
          ],
        );

        final config =
            await MelosWorkspaceConfig.fromWorkspaceRoot(mockWorkspaceRootDir);
        final workspace = await MelosWorkspace.fromConfig(
          config,
          logger: TestLogger().toMelosLogger(),
        );

        expect(
          workspace.filteredPackages.values,
          [packageNamed('a')],
        );
      }),
    );

    test(
      'load workspace config when workspace contains broken symlink',
      () async {
        final workspaceDir = await createTemporaryWorkspace();

        final link = Link(p.join(workspaceDir.path, 'link'));
        await link.create(p.join(workspaceDir.path, 'does-not-exist'));

        await MelosWorkspace.fromConfig(
          await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir),
          logger: TestLogger().toMelosLogger(),
        );
      },
    );

    group('locate packages', () {
      test('in workspace root', () async {
        final workspaceDir = await createTemporaryWorkspace(
          configBuilder: (path) => MelosWorkspaceConfig.fromYaml(
            const {
              'name': 'test',
              'packages': ['.'],
            },
            path: path,
          ),
        );

        await createProject(
          workspaceDir,
          const PubSpec(name: 'a'),
          path: '.',
        );

        final workspace = await MelosWorkspace.fromConfig(
          await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir),
          logger: TestLogger().toMelosLogger(),
        );

        expect(workspace.allPackages['a'], isNotNull);
      });

      test('in child directory', () async {
        final workspaceDir = await createTemporaryWorkspace(
          configBuilder: (path) => MelosWorkspaceConfig.fromYaml(
            const {
              'name': 'test',
              'packages': ['packages/a'],
            },
            path: path,
          ),
        );

        await createProject(workspaceDir, const PubSpec(name: 'a'));

        final workspace = await MelosWorkspace.fromConfig(
          await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir),
          logger: TestLogger().toMelosLogger(),
        );

        expect(workspace.allPackages['a'], isNotNull);
      });
    });

    group('sdkPath', () {
      test('use SDK path from environment variable', () async {
        withMockPlatform(
          () {
            final workspace = VirtualWorkspaceBuilder('').build();
            expect(workspace.sdkPath, '/sdks/env');
          },
          platform: FakePlatform.fromPlatform(const LocalPlatform())
            ..environment[EnvironmentVariableKey.melosSdkPath] = '/sdks/env',
        );
      });

      test('prepend SDK bin directory to ${EnvironmentVariableKey.path}',
          () async {
        withMockPlatform(
          () {
            final workspace = VirtualWorkspaceBuilder(
              '',
              sdkPath: '/sdk',
            ).build();
            expect(workspace.path, '/sdk$pathEnvVarSeparator/bin');
          },
          platform: FakePlatform.fromPlatform(const LocalPlatform())
            ..environment[EnvironmentVariableKey.path] = '/bin',
        );
      });
    });

    group('package filtering', () {
      group('--include-dependencies', () {
        test(
          'includes the scoped package',
          withMockFs(() async {
            final workspaceDir = createMockWorkspaceFs(
              packages: [
                MockPackageFs(name: 'a', dependencies: ['b']),
                MockPackageFs(name: 'b'),
              ],
            );
            final config =
                await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
            final workspace = await MelosWorkspace.fromConfig(
              config,
              packageFilters: PackageFilters(
                scope: [
                  createGlob('b', currentDirectoryPath: workspaceDir.path),
                ],
                includeDependencies: true,
              ),
              logger: TestLogger().toMelosLogger(),
            );

            expect(workspace.filteredPackages.values, [packageNamed('b')]);
          }),
        );

        test(
          'includes direct dependencies',
          withMockFs(() async {
            final workspaceDir = createMockWorkspaceFs(
              packages: [
                MockPackageFs(name: 'a', dependencies: ['b']),
                MockPackageFs(name: 'b'),
              ],
            );
            final config =
                await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
            final workspace = await MelosWorkspace.fromConfig(
              config,
              packageFilters: PackageFilters(
                scope: [
                  createGlob('a', currentDirectoryPath: workspaceDir.path),
                ],
                includeDependencies: true,
              ),
              logger: TestLogger().toMelosLogger(),
            );

            expect(
              workspace.filteredPackages.values,
              unorderedEquals(<Matcher>[
                packageNamed('a'),
                packageNamed('b'),
              ]),
            );
          }),
        );

        test(
          'includes transient dependencies',
          withMockFs(() async {
            final workspaceDir = createMockWorkspaceFs(
              packages: [
                MockPackageFs(name: 'a', dependencies: ['b']),
                MockPackageFs(name: 'b', dependencies: ['c']),
                MockPackageFs(name: 'c'),
              ],
            );
            final config =
                await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
            final workspace = await MelosWorkspace.fromConfig(
              config,
              packageFilters: PackageFilters(
                scope: [
                  createGlob('a', currentDirectoryPath: workspaceDir.path),
                ],
                includeDependencies: true,
              ),
              logger: TestLogger().toMelosLogger(),
            );

            expect(
              workspace.filteredPackages.values,
              containsAll(<Matcher>[
                packageNamed('a'),
                packageNamed('b'),
                packageNamed('c'), // This dep is transitive
              ]),
            );
          }),
        );

        test(
          'does not include duplicates',
          withMockFs(() async {
            final workspaceDir = createMockWorkspaceFs(
              packages: [
                MockPackageFs(name: 'a', dependencies: ['b', 'c']),
                MockPackageFs(name: 'b', dependencies: ['d']),
                MockPackageFs(name: 'c', dependencies: ['d']),
                MockPackageFs(name: 'd'),
              ],
            );
            final config =
                await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
            final workspace = await MelosWorkspace.fromConfig(
              config,
              packageFilters: PackageFilters(
                scope: [
                  createGlob('a', currentDirectoryPath: workspaceDir.path),
                ],
                includeDependencies: true,
              ),
              logger: TestLogger().toMelosLogger(),
            );

            expect(workspace.filteredPackages.values, hasLength(4));
            expect(
              workspace.filteredPackages.values,
              isNot(containsDuplicates),
            );
          }),
        );
      });

      group('--include-dependents', () {
        test(
          'includes the scoped package',
          withMockFs(() async {
            final workspaceDir = createMockWorkspaceFs(
              packages: [
                MockPackageFs(name: 'a', dependencies: ['b']),
                MockPackageFs(name: 'b'),
              ],
            );
            final config =
                await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
            final workspace = await MelosWorkspace.fromConfig(
              config,
              packageFilters: PackageFilters(
                scope: [
                  createGlob('a', currentDirectoryPath: workspaceDir.path),
                ],
                includeDependents: true,
              ),
              logger: TestLogger().toMelosLogger(),
            );

            expect(workspace.filteredPackages.values, [packageNamed('a')]);
          }),
        );

        test(
          'includes direct dependents',
          withMockFs(() async {
            final workspaceDir = createMockWorkspaceFs(
              packages: [
                MockPackageFs(name: 'a', dependencies: ['b']),
                MockPackageFs(name: 'b'),
              ],
            );
            final config =
                await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
            final workspace = await MelosWorkspace.fromConfig(
              config,
              packageFilters: PackageFilters(
                scope: [
                  createGlob('b', currentDirectoryPath: workspaceDir.path),
                ],
                includeDependents: true,
              ),
              logger: TestLogger().toMelosLogger(),
            );

            expect(workspace.filteredPackages.values, hasLength(2));
            expect(
              workspace.filteredPackages.values,
              containsAll(<Matcher>[packageNamed('a'), packageNamed('b')]),
            );
          }),
        );

        test(
          'includes transient dependents',
          withMockFs(() async {
            final workspaceDir = createMockWorkspaceFs(
              packages: [
                MockPackageFs(name: 'a', dependencies: ['b']),
                MockPackageFs(name: 'b', dependencies: ['c']),
                MockPackageFs(name: 'c'),
              ],
            );
            final config =
                await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
            final workspace = await MelosWorkspace.fromConfig(
              config,
              packageFilters: PackageFilters(
                scope: [
                  createGlob('c', currentDirectoryPath: workspaceDir.path),
                ],
                includeDependents: true,
              ),
              logger: TestLogger().toMelosLogger(),
            );

            expect(
              workspace.filteredPackages.values,
              containsAll(<Matcher>[
                packageNamed('a'),
                packageNamed('b'),
                packageNamed('c'), // This dep is transitive
              ]),
            );
          }),
        );

        test(
          'does not include duplicates',
          withMockFs(() async {
            final workspaceDir = createMockWorkspaceFs(
              packages: [
                MockPackageFs(name: 'a', dependencies: ['b', 'c']),
                MockPackageFs(name: 'b', dependencies: ['d']),
                MockPackageFs(name: 'c', dependencies: ['d']),
                MockPackageFs(name: 'd'),
              ],
            );
            final config =
                await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
            final workspace = await MelosWorkspace.fromConfig(
              config,
              packageFilters: PackageFilters(
                scope: [
                  createGlob('d', currentDirectoryPath: workspaceDir.path),
                ],
                includeDependents: true,
              ),
              logger: TestLogger().toMelosLogger(),
            );

            expect(workspace.filteredPackages.values, hasLength(4));
            expect(
              workspace.filteredPackages.values,
              isNot(containsDuplicates),
            );
          }),
        );
      });
    });

    group('resolveSdkPath', () {
      final workspacePath = p.normalize('/workspace');
      final configSdkPath = p.normalize('/sdks/config');
      final envSdkPath = p.normalize('/sdks/env');
      final commandSdkPath = p.normalize('/sdks/command-line');

      test('should return null if no sdk path is provided', () {
        expect(
          resolveSdkPath(
            configSdkPath: null,
            envSdkPath: null,
            commandSdkPath: null,
            workspacePath: workspacePath,
          ),
          null,
        );
      });

      test('commandSdkPath has precedence over envSdkPath', () {
        expect(
          resolveSdkPath(
            configSdkPath: configSdkPath,
            envSdkPath: envSdkPath,
            commandSdkPath: commandSdkPath,
            workspacePath: workspacePath,
          ),
          commandSdkPath,
        );
      });

      test('envSdkPath has precedence over configSdkPath', () {
        expect(
          resolveSdkPath(
            configSdkPath: configSdkPath,
            envSdkPath: envSdkPath,
            commandSdkPath: null,
            workspacePath: workspacePath,
          ),
          envSdkPath,
        );
      });

      test('use configSdkPath if no other sdkPath is specified', () {
        expect(
          resolveSdkPath(
            configSdkPath: configSdkPath,
            envSdkPath: null,
            commandSdkPath: null,
            workspacePath: workspacePath,
          ),
          configSdkPath,
        );
      });

      test('allow trailing path separator in sdk paths', () {
        expect(
          resolveSdkPath(
            configSdkPath: null,
            envSdkPath: null,
            commandSdkPath: p.join(commandSdkPath, ''),
            workspacePath: workspacePath,
          ),
          commandSdkPath,
        );
        expect(
          resolveSdkPath(
            configSdkPath: null,
            envSdkPath: p.join(envSdkPath, ''),
            commandSdkPath: null,
            workspacePath: workspacePath,
          ),
          envSdkPath,
        );
        expect(
          resolveSdkPath(
            configSdkPath: p.join(configSdkPath, ''),
            envSdkPath: null,
            commandSdkPath: null,
            workspacePath: workspacePath,
          ),
          configSdkPath,
        );
      });

      test('create absolute path from a relative sdk path', () {
        expect(
          resolveSdkPath(
            configSdkPath: null,
            envSdkPath: null,
            commandSdkPath: 'sdk',
            workspacePath: workspacePath,
          ),
          p.join(workspacePath, 'sdk'),
        );
        expect(
          resolveSdkPath(
            configSdkPath: null,
            envSdkPath: 'sdk',
            commandSdkPath: null,
            workspacePath: workspacePath,
          ),
          p.join(workspacePath, 'sdk'),
        );
        expect(
          resolveSdkPath(
            configSdkPath: 'sdk',
            envSdkPath: null,
            commandSdkPath: null,
            workspacePath: workspacePath,
          ),
          p.join(workspacePath, 'sdk'),
        );
      });

      test('return null if sdk path is `auto`', () {
        expect(
          resolveSdkPath(
            configSdkPath: autoSdkPathOptionValue,
            envSdkPath: null,
            commandSdkPath: null,
            workspacePath: workspacePath,
          ),
          null,
        );
        expect(
          resolveSdkPath(
            configSdkPath: null,
            envSdkPath: autoSdkPathOptionValue,
            commandSdkPath: null,
            workspacePath: workspacePath,
          ),
          null,
        );
        expect(
          resolveSdkPath(
            configSdkPath: null,
            envSdkPath: null,
            commandSdkPath: autoSdkPathOptionValue,
            workspacePath: workspacePath,
          ),
          null,
        );
        expect(
          resolveSdkPath(
            configSdkPath: autoSdkPathOptionValue,
            envSdkPath: autoSdkPathOptionValue,
            commandSdkPath: autoSdkPathOptionValue,
            workspacePath: workspacePath,
          ),
          null,
        );
      });
    });
  });
}
