import 'dart:io';

import 'package:melos/src/common/environment_variable_key.dart';
import 'package:melos/src/common/io.dart';
import 'package:melos/src/common/utils.dart';
import 'package:melos/src/logging.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart' show FakePlatform;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'matchers.dart';
import 'mock_env.dart';
import 'utils.dart';

void main() {
  group('currentDartVersion', () {
    test('returns correct version', () {
      // We assume that the test is executed with the version of Dart that
      // is on the path.
      expect(
        currentDartVersion('dart'),
        Version.parse(Platform.version.split(' ')[0]),
      );
    });

    test('supports absolute paths', () {
      // We assume that the test is executed with the version of Dart that
      // is on the path, which is what the dart_wrapper uses. The wrapper
      // just makes it easy to construct an absolute path.
      final dartWrapper = p.join(
        Directory.current.path,
        'test/test_assets/dart_wrapper',
      );
      expect(
        currentDartVersion(dartWrapper),
        Version.parse(Platform.version.split(' ')[0]),
      );
    });
  });

  group('pubCommandExecArgs', () {
    test('no sdk path specified', () {
      final workspace = VirtualWorkspaceBuilder('').build();

      expect(
        pubCommandExecArgs(
          workspace: workspace,
          useFlutter: true,
        ),
        ['flutter', 'pub'],
      );
      expect(
        pubCommandExecArgs(
          workspace: workspace,
          useFlutter: false,
        ),
        [if (isPubSubcommand(workspace: workspace)) 'dart', 'pub'],
      );
    });

    test('with sdk path specified', () {
      final sdkPath = p.join('flutter_sdks', 'stable');
      final workspace = VirtualWorkspaceBuilder('', sdkPath: sdkPath).build();

      expect(
        pubCommandExecArgs(
          workspace: workspace,
          useFlutter: true,
        ),
        [p.join(sdkPath, 'bin', 'flutter'), 'pub'],
      );
      expect(
        pubCommandExecArgs(
          workspace: workspace,
          useFlutter: false,
        ),
        [p.join(sdkPath, 'bin', 'dart'), 'pub'],
      );
    });
  });

  group('startProcess', () {
    test('runs command chain in single shell', () async {
      final workspaceDir = await createTemporaryWorkspace(
        workspacePackages: [],
      );
      final testDir = p.join(workspaceDir.path, 'test');

      ensureDir(testDir);

      final logger = TestLogger();
      await startCommand(
        [
          'cd',
          'test',
          '&&',
          if (Platform.isWindows) 'cd' else 'pwd',
        ],
        logger: logger.toMelosLogger(),
        workingDirectory: workspaceDir.path,
      );

      expect(
        logger.output.normalizeLines(),
        ignoringAnsii('$testDir\n'),
      );
    });
  });

  group('resolveEnvironmentVariableReferences', () {
    const environment = {'FOO': 'bar', 'FOOBAR': 'baz'};

    group('on POSIX', () {
      test(
        'leaves references untouched so the shell expands them natively',
        withMockPlatform(
          () async {
            expect(
              resolveEnvironmentVariableReferences(
                r'echo $FOO ${FOO} %FOO%',
                environment: environment,
              ),
              r'echo $FOO ${FOO} %FOO%',
            );
          },
          platform: FakePlatform(operatingSystem: 'linux'),
        ),
      );
    });

    group('on Windows', () {
      test(
        'substitutes each reference syntax with its value',
        withMockPlatform(
          () async {
            expect(
              resolveEnvironmentVariableReferences(
                r'echo $FOO',
                environment: environment,
              ),
              'echo bar',
            );
            expect(
              resolveEnvironmentVariableReferences(
                r'echo ${FOO}',
                environment: environment,
              ),
              'echo bar',
            );
            expect(
              resolveEnvironmentVariableReferences(
                'echo %FOO%',
                environment: environment,
              ),
              'echo bar',
            );
          },
          platform: FakePlatform(
            operatingSystem: 'windows',
            environment: const {},
          ),
        ),
      );

      test(
        'only substitutes whole-identifier references',
        withMockPlatform(
          () async {
            expect(
              resolveEnvironmentVariableReferences(
                r'echo $FOOBAR',
                environment: environment,
              ),
              'echo baz',
            );
            expect(
              resolveEnvironmentVariableReferences(
                r'echo $FOO_BAR',
                environment: environment,
              ),
              r'echo $FOO_BAR',
            );
          },
          platform: FakePlatform(
            operatingSystem: 'windows',
            environment: const {},
          ),
        ),
      );

      test(
        'leaves unknown variables untouched',
        withMockPlatform(
          () async {
            expect(
              resolveEnvironmentVariableReferences(
                r'echo $BAR',
                environment: const {},
              ),
              r'echo $BAR',
            );
          },
          platform: FakePlatform(
            operatingSystem: 'windows',
            environment: const {},
          ),
        ),
      );

      test(
        'substitutes variables inherited from the parent process environment',
        withMockPlatform(
          () async {
            expect(
              resolveEnvironmentVariableReferences(
                r'echo $INHERITED',
                environment: const {},
              ),
              'echo qux',
            );
          },
          platform: FakePlatform(
            operatingSystem: 'windows',
            environment: const {'INHERITED': 'qux'},
          ),
        ),
      );

      test(
        'prefers the script environment over an inherited value',
        withMockPlatform(
          () async {
            expect(
              resolveEnvironmentVariableReferences(
                r'echo $FOO',
                environment: environment,
              ),
              'echo bar',
            );
          },
          platform: FakePlatform(
            operatingSystem: 'windows',
            environment: const {'FOO': 'inherited'},
          ),
        ),
      );
    });
  });

  group('getPubCacheDirectory', () {
    test(
      'uses PUB_CACHE when set',
      withMockPlatform(
        () {
          expect(getPubCacheDirectory(), p.normalize('/custom/.pub-cache'));
        },
        platform: FakePlatform(
          operatingSystem: 'linux',
          environment: const {
            EnvironmentVariableKey.pubCache: '/custom/.pub-cache',
            'HOME': '/root',
          },
        ),
      ),
    );

    test(
      'defaults to HOME/.pub-cache on POSIX',
      withMockPlatform(
        () {
          expect(getPubCacheDirectory(), p.join('/root', '.pub-cache'));
        },
        platform: FakePlatform(
          operatingSystem: 'linux',
          environment: const {'HOME': '/root'},
        ),
      ),
    );

    test(
      'defaults to LOCALAPPDATA/Pub/Cache on Windows',
      withMockPlatform(
        () {
          expect(
            getPubCacheDirectory(),
            p.join(r'C:\Users\me\AppData\Local', 'Pub', 'Cache'),
          );
        },
        platform: FakePlatform(
          operatingSystem: 'windows',
          environment: const {
            'LOCALAPPDATA': r'C:\Users\me\AppData\Local',
          },
        ),
      ),
    );
  });

  group('applyPubCacheOverride', () {
    test(
      'rewrites a missing default pub-cache path to PUB_CACHE',
      withMockPlatform(
        () {
          final resolved = p.join(
            '/root',
            '.pub-cache',
            'hosted',
            'pub.dev',
            'melos-6.1.0',
          );
          expect(
            applyPubCacheOverride(resolved),
            p.join(
              '/custom/.pub-cache',
              'hosted',
              'pub.dev',
              'melos-6.1.0',
            ),
          );
        },
        platform: FakePlatform(
          operatingSystem: 'linux',
          environment: const {
            EnvironmentVariableKey.pubCache: '/custom/.pub-cache',
            'HOME': '/root',
          },
        ),
      ),
    );

    test(
      'keeps the isolate-resolved path when PUB_CACHE is unset',
      withMockPlatform(
        () {
          final resolved = p.join(
            '/root',
            '.pub-cache',
            'hosted',
            'pub.dev',
            'melos-6.1.0',
          );
          expect(applyPubCacheOverride(resolved), resolved);
        },
        platform: FakePlatform(
          operatingSystem: 'linux',
          environment: const {'HOME': '/root'},
        ),
      ),
    );

    test(
      'keeps a path that is not under the default pub-cache',
      withMockPlatform(
        () {
          const resolved = '/src/melos/packages/melos';
          expect(applyPubCacheOverride(resolved), resolved);
        },
        platform: FakePlatform(
          operatingSystem: 'linux',
          environment: const {
            EnvironmentVariableKey.pubCache: '/custom/.pub-cache',
            'HOME': '/root',
          },
        ),
      ),
    );

    test(
      'rewrites a Windows Roaming cache path even when Local is set',
      withMockPlatform(
        () {
          final resolved = p.join(
            r'C:\Users\me\AppData\Roaming',
            'Pub',
            'Cache',
            'hosted',
            'pub.dev',
            'melos-6.1.0',
          );
          expect(
            applyPubCacheOverride(resolved),
            p.join(
              r'C:\custom\.pub-cache',
              'hosted',
              'pub.dev',
              'melos-6.1.0',
            ),
          );
        },
        platform: FakePlatform(
          operatingSystem: 'windows',
          environment: const {
            EnvironmentVariableKey.pubCache: r'C:\custom\.pub-cache',
            'LOCALAPPDATA': r'C:\Users\me\AppData\Local',
            'APPDATA': r'C:\Users\me\AppData\Roaming',
          },
        ),
      ),
    );
  });

  group('mergeYaml', () {
    test('correctly handles value overriding', () {
      final base = {
        'abc': 123,
        'def': [4, 5, 6],
        'ghi': {'j': 'k', 'l': 'm', 'n': 'o'},
        'pqr': ['1', '2', '3'],
        'stu': 'aStringValue',
        'vwx': true,
      };
      const overlay = {
        'abc': 098,
        'def': [7],
        'ghi': {'j': 'i', 'l': 'm', 'n': 'o', 'p': 'q'},
        'pqr': 'differentType',
        'stu': ['another', 'different', 'type'],
        'yza': false,
      };
      mergeMap(base, overlay);
      expect(base, const {
        'abc': 098,
        'def': [4, 5, 6, 7],
        'ghi': {'j': 'i', 'l': 'm', 'n': 'o', 'p': 'q'},
        'pqr': 'differentType',
        'stu': ['another', 'different', 'type'],
        'vwx': true,
        'yza': false,
      });
    });
  });
}
