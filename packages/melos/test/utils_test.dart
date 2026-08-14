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

  group('applyPubCacheOverride', () {
    String packagePath(String cache) =>
        p.join(cache, 'hosted', 'pub.dev', 'melos-6.1.0');

    test('rewrites a stale default pub-cache path into PUB_CACHE', () async {
      final pubCacheDir = createTestTempDir();
      final rewrittenRoot = packagePath(pubCacheDir.path);
      Directory(p.join(rewrittenRoot, 'templates')).createSync(recursive: true);

      await withMockPlatform(
        () {
          expect(
            applyPubCacheOverride(
              packagePath(p.join('/root', '.pub-cache')),
              probeSubdirectory: 'templates',
            ),
            p.normalize(rewrittenRoot),
          );
        },
        platform: FakePlatform(
          operatingSystem: 'linux',
          environment: {
            EnvironmentVariableKey.pubCache: pubCacheDir.path,
            'HOME': '/root',
          },
        ),
      )();
    });

    test('keeps a resolved path that still contains the probe', () async {
      final defaultCacheDir = createTestTempDir();
      final resolvedRoot = packagePath(defaultCacheDir.path);
      Directory(p.join(resolvedRoot, 'templates')).createSync(recursive: true);
      final pubCacheDir = createTestTempDir();

      await withMockPlatform(
        () {
          expect(
            applyPubCacheOverride(resolvedRoot, probeSubdirectory: 'templates'),
            resolvedRoot,
          );
        },
        platform: FakePlatform(
          operatingSystem: 'linux',
          environment: {
            EnvironmentVariableKey.pubCache: pubCacheDir.path,
            'HOME': '/root',
          },
        ),
      )();
    });

    test(
      'keeps the isolate-resolved path when PUB_CACHE is unset',
      withMockPlatform(
        () {
          final resolved = packagePath(p.join('/root', '.pub-cache'));
          expect(
            applyPubCacheOverride(resolved, probeSubdirectory: 'templates'),
            resolved,
          );
        },
        platform: FakePlatform(
          operatingSystem: 'linux',
          environment: const {'HOME': '/root'},
        ),
      ),
    );

    test('keeps a path that is not under the default pub-cache', () async {
      final pubCacheDir = createTestTempDir();
      Directory(
        p.join(packagePath(pubCacheDir.path), 'templates'),
      ).createSync(recursive: true);

      await withMockPlatform(
        () {
          const resolved = '/src/melos/packages/melos';
          expect(
            applyPubCacheOverride(resolved, probeSubdirectory: 'templates'),
            resolved,
          );
        },
        platform: FakePlatform(
          operatingSystem: 'linux',
          environment: {
            EnvironmentVariableKey.pubCache: pubCacheDir.path,
            'HOME': '/root',
          },
        ),
      )();
    });

    test('keeps the resolved path when PUB_CACHE lacks the probe', () async {
      final pubCacheDir = createTestTempDir();

      await withMockPlatform(
        () {
          final resolved = packagePath(p.join('/root', '.pub-cache'));
          expect(
            applyPubCacheOverride(resolved, probeSubdirectory: 'templates'),
            resolved,
          );
        },
        platform: FakePlatform(
          operatingSystem: 'linux',
          environment: {
            EnvironmentVariableKey.pubCache: pubCacheDir.path,
            'HOME': '/root',
          },
        ),
      )();
    });

    test(
      'keeps a resolved path that is already inside a nested PUB_CACHE',
      () async {
        final homeDir = createTestTempDir();
        final pubCache = p.join(homeDir.path, '.pub-cache', 'ci');
        final resolved = packagePath(pubCache);

        await withMockPlatform(
          () {
            expect(
              applyPubCacheOverride(resolved, probeSubdirectory: 'templates'),
              resolved,
            );
          },
          platform: FakePlatform(
            operatingSystem: 'linux',
            environment: {
              EnvironmentVariableKey.pubCache: pubCache,
              'HOME': homeDir.path,
            },
          ),
        )();
      },
    );

    test(
      'rewrites a Windows Roaming cache path even when Local is set',
      () async {
        final localDir = createTestTempDir();
        final roamingDir = createTestTempDir();
        final pubCacheDir = createTestTempDir();
        final rewrittenRoot = packagePath(pubCacheDir.path);
        Directory(
          p.join(rewrittenRoot, 'templates'),
        ).createSync(recursive: true);
        final resolved = packagePath(p.join(roamingDir.path, 'Pub', 'Cache'));

        await withMockPlatform(
          () {
            expect(
              applyPubCacheOverride(resolved, probeSubdirectory: 'templates'),
              p.normalize(rewrittenRoot),
            );
          },
          platform: FakePlatform(
            operatingSystem: 'windows',
            environment: {
              EnvironmentVariableKey.pubCache: pubCacheDir.path,
              'LOCALAPPDATA': localDir.path,
              'APPDATA': roamingDir.path,
            },
          ),
        )();
      },
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

  group('prompts', () {
    // Regression test for https://github.com/invertase/melos/issues/1057.
    //
    // Some environments report `stdin.hasTerminal == true` while any actual
    // terminal operation (such as reading the echo mode) fails with a
    // `StdinException`. Prompting must degrade to the non-interactive
    // defaults in that case instead of crashing.
    test('fall back to defaults when the terminal throws StdinException', () {
      IOOverrides.runZoned(
        () {
          expect(
            promptBool(defaultsToWithoutPrompt: true),
            isTrue,
          );
          expect(
            promptInput('message', defaultsTo: 'default'),
            'default',
          );
          expect(
            () => promptBool(requirePrompt: true),
            throwsA(isA<PromptException>()),
          );
        },
        stdin: _BrokenStdin.new,
      );
    });
  });
}

class _BrokenStdin implements Stdin {
  @override
  bool get hasTerminal => true;

  @override
  bool get echoMode => throw const StdinException(
    'Error getting terminal echo mode, OS Error: Operation not supported by '
    'device, errno = 19',
  );

  @override
  set echoMode(bool value) => throw const StdinException(
    'Error setting terminal echo mode, OS Error: Operation not supported by '
    'device, errno = 19',
  );

  @override
  bool get lineMode => throw const StdinException(
    'Error getting terminal line mode, OS Error: Operation not supported by '
    'device, errno = 19',
  );

  @override
  set lineMode(bool value) => throw const StdinException(
    'Error setting terminal line mode, OS Error: Operation not supported by '
    'device, errno = 19',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
