import 'dart:io';

import 'package:melos/src/common/io.dart';
import 'package:melos/src/common/utils.dart';
import 'package:melos/src/logging.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'matchers.dart';
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

      final prefix = Platform.isMacOS ? '/private' : '';
      expect(
        logger.output.normalizeLines(),
        ignoringAnsii('$prefix$testDir\n'),
      );
    });
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
