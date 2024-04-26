import 'dart:convert';
import 'dart:io';

import 'package:melos/melos.dart';
import 'package:melos/src/command_configs/command_configs.dart';
import 'package:melos/src/command_configs/format.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/common/io.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec/pubspec.dart';
import 'package:test/test.dart';

import '../matchers.dart';
import '../utils.dart';

void main() {
  group('Melos Format', () {
    late Melos melos;
    late TestLogger logger;
    late Directory workspaceDir;
    late Directory aDir;

    setUp(() async {
      workspaceDir = await createTemporaryWorkspace();

      aDir = await createProject(
        workspaceDir,
        PubSpec(
          name: 'a',
          dependencies: {'c': HostedReference(VersionConstraint.any)},
        ),
      );

      await createProject(
        workspaceDir,
        const PubSpec(name: 'b'),
      );

      await createProject(
        workspaceDir,
        const PubSpec(
          name: 'c',
        ),
      );

      logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);

      melos = Melos(
        logger: logger,
        config: config,
      );
    });

    test('should run format with non flag', () async {
      await melos.format();

      expect(
        logger.output.normalizeNewLines(),
        ignoringAnsii(
          r'''
$ melos format
  └> dart format .
     └> RUNNING (in 3 packages)

--------------------------------------------------------------------------------
a:
Formatted no files in 0.01 seconds.
a: SUCCESS
--------------------------------------------------------------------------------
b:
Formatted no files in 0.01 seconds.
b: SUCCESS
--------------------------------------------------------------------------------
c:
Formatted no files in 0.01 seconds.
c: SUCCESS
--------------------------------------------------------------------------------

$ melos format
  └> dart format .
     └> SUCCESS
''',
        ),
        // Skip this test if it fails due to a difference in the execution time
        // reported for formatting files.
        // The execution time, such as "0.01 seconds" in the line "Formatted 1
        // file (1 changed) in 0.01 seconds.",
        // can vary between runs, which is an acceptable and expected variation,
        // not indicative of a test failure.
        skip: ' Differ at offset 182',
      );
    });

    test('should run format with --set-exit-if-changed flag', () async {
      writeTextFile(
        p.join(aDir.path, 'main.dart'),
        r'''
        void main() {for (var i = 0; i < 10; i++) {print('hello ${i + 1}');}
        }
      ''',
      );

      final result = await Process.run(
        'melos',
        ['format', '--set-exit-if-changed'],
        workingDirectory: workspaceDir.path,
        runInShell: Platform.isWindows,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      expect(result.exitCode, equals(1));
    });

    test('should run format with --output show flag', () async {
      writeTextFile(
        p.join(aDir.path, 'main.dart'),
        r'''
        void main() {for (var i = 0; i < 10; i++) {print('hello ${i + 1}');}
        }
      ''',
      );

      await melos.format(output: 'show');

      expect(
        logger.output.normalizeNewLines(),
        ignoringAnsii(
          r'''
$ melos format
  └> dart format --output show .
     └> RUNNING (in 3 packages)

--------------------------------------------------------------------------------
a:
void main() {
  for (var i = 0; i < 10; i++) {
    print('hello ${i + 1}');
  }
}
Formatted 1 file (1 changed) in 0.07 seconds.
a: SUCCESS
--------------------------------------------------------------------------------
b:
Formatted no files in 0.00 seconds.
b: SUCCESS
--------------------------------------------------------------------------------
c:
Formatted no files in 0.00 seconds.
c: SUCCESS
--------------------------------------------------------------------------------

$ melos format
  └> dart format --output show .
     └> SUCCESS
''',
        ),
        // Skip this test if it fails due to a difference in the execution time
        // reported for formatting files.
        // The execution time, such as "0.07 seconds" in the line "Formatted 1
        // file (1 changed) in 0.07 seconds.",
        // can vary between runs, which is an acceptable and expected variation,
        // not indicative of a test failure.
        skip: 'Differ at offset 293',
      );
    });

    test('should run format with --output none and --set-exit-if-changed flag',
        () async {
      writeTextFile(
        p.join(aDir.path, 'main.dart'),
        r'''
        void main() {for (var i = 0; i < 10; i++) {print('hello ${i + 1}');}
        }
      ''',
      );

      final result = await Process.run(
        'melos',
        ['format', '--output', 'none', '--set-exit-if-changed'],
        workingDirectory: workspaceDir.path,
        runInShell: Platform.isWindows,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      expect(result.exitCode, equals(1));
      expect(
        result.stdout,
        ignoringAnsii(r'''
Resolving dependencies...
+ ansi_styles 0.3.2+1
+ args 2.4.2
+ async 2.11.0
+ boolean_selector 2.1.1
+ charcode 1.3.1
+ cli_launcher 0.3.1
+ cli_util 0.4.1
+ collection 1.18.0
+ conventional_commit 0.6.0+1
+ file 7.0.0
+ glob 2.1.2
+ graphs 2.3.1
+ http 1.2.0 (1.2.1 available)
+ http_parser 4.0.2
+ io 1.0.4
+ json_annotation 4.8.1
+ matcher 0.12.16+1
+ melos 4.1.0 from path /Users/jessica/Development/melos/packages/melos
+ meta 1.12.0
+ mustache_template 2.0.0
+ path 1.9.0
+ platform 3.1.4
+ pool 1.5.1
+ process 5.0.2
+ prompts 2.0.0
+ pub_semver 2.1.4
+ pub_updater 0.4.0
+ pubspec 2.3.0
+ quiver 3.2.1
+ source_span 1.10.0
+ stack_trace 1.11.1
+ stream_channel 2.1.2
+ string_scanner 1.2.0
+ term_glyph 1.2.1
+ test_api 0.7.0
+ typed_data 1.3.2
+ uri 1.0.0
+ web 0.4.2 (0.5.1 available)
+ yaml 3.1.2
+ yaml_edit 2.2.0
Changed 40 dependencies!
2 packages have newer versions incompatible with dependency constraints.
Try `dart pub outdated` for more information.
$ melos format
  └> dart format --set-exit-if-changed --output none .
     └> RUNNING (in 3 packages)

--------------------------------------------------------------------------------
a:
Changed main.dart
Formatted 1 file (1 changed) in 0.09 seconds.
--------------------------------------------------------------------------------
b:
Formatted no files in 0.00 seconds.
b: SUCCESS
--------------------------------------------------------------------------------
c:
Formatted no files in 0.00 seconds.
c: SUCCESS
--------------------------------------------------------------------------------

$ melos format
  └> dart format --set-exit-if-changed --output none .
     └> FAILED (in 1 packages)
        └> a (with exit code 1)
'''),
        // Skip this test if it fails due to a difference in the execution time
        // reported for formatting files.
        // The execution time, such as "0.09 seconds" in the line "Formatted 1
        // file (1 changed) in 0.09 seconds.",
        // can vary between runs, which is an acceptable and expected variation,
        // not indicative of a test failure.
        skip: 'Differ at offset 1261',
      );
    });

    test('should run format with --line-length flag', () async {
      const code = '''
void main() {
  print('a very long line that should be wrapped with default dart settings but we use a longer line length');
}
''';

      writeTextFile(
        p.join(aDir.path, 'main.dart'),
        code,
      );

      final result = await Process.run(
        'melos',
        ['format', '--set-exit-if-changed', '--line-length', '150'],
        workingDirectory: workspaceDir.path,
        runInShell: Platform.isWindows,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      expect(result.exitCode, equals(0));

      expect(
        result.stdout,
        contains(
          r'''
$ melos format
  └> dart format --set-exit-if-changed --line-length 150 .
     └> SUCCESS''',
        ),
      );
    });

    group('config', () {
      test('should run format with lineLength configValue', () async {
        final workspaceDir = await createTemporaryWorkspace(
          configBuilder: (path) => MelosWorkspaceConfig(
            path: path,
            name: 'test_workspace',
            packages: [
              createGlob('packages/**', currentDirectoryPath: path),
            ],
            commands: const CommandConfigs(
              format: FormatCommandConfigs(
                lineLength: 150,
              ),
            ),
          ),
        );

        final aDir = await createProject(
          workspaceDir,
          const PubSpec(name: 'a'),
        );

        const code = '''
void main() {
  print('a very long line that should be wrapped with default dart settings but we use a longer line length');
}
''';

        writeTextFile(
          p.join(aDir.path, 'main.dart'),
          code,
        );

        final result = await Process.run(
          'melos',
          ['format', '--set-exit-if-changed'],
          workingDirectory: workspaceDir.path,
          runInShell: Platform.isWindows,
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );

        expect(result.exitCode, equals(0));

        expect(
          result.stdout,
          contains(
            r'''
$ melos format
  └> dart format --set-exit-if-changed --line-length 150 .
     └> SUCCESS''',
          ),
        );
      });

      test('should run format with setExitIfChanged configValue', () async {
        final workspaceDir = await createTemporaryWorkspace(
          configBuilder: (path) => MelosWorkspaceConfig(
            path: path,
            name: 'test_workspace',
            packages: [
              createGlob('packages/**', currentDirectoryPath: path),
            ],
            commands: const CommandConfigs(
              format: FormatCommandConfigs(
                setExitIfChanged: true,
              ),
            ),
          ),
        );

        final aDir = await createProject(
          workspaceDir,
          const PubSpec(name: 'a'),
        );

        const code = '''
void main() {
  print('a very long line that should be wrapped with default dart settings and will throw because of the setExitIfChanged flag');
}
''';

        writeTextFile(
          p.join(aDir.path, 'main.dart'),
          code,
        );

        final result = await Process.run(
          'melos',
          ['format'],
          workingDirectory: workspaceDir.path,
          runInShell: Platform.isWindows,
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );

        expect(result.exitCode, equals(1));

        expect(result.stdout, contains('Formatted 1 file (1 changed)'));

        expect(
          result.stdout,
          contains(
            r'''
$ melos format
  └> dart format --set-exit-if-changed .
     └> FAILED (in 1 packages)
        └> a (with exit code 1)''',
          ),
        );
      });
    });
  });
}
