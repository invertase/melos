import 'dart:io';

import 'package:melos/melos.dart';
import 'package:melos/src/common/io.dart';
import 'package:melos/src/common/utils.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

import '../matchers.dart';
import '../utils.dart';

void main() {
  group('Melos Analyze', () {
    late Melos melos;
    late TestLogger logger;
    late Directory workspaceDir;
    late Directory aDir;

    setUp(() async {
      workspaceDir = await createTemporaryWorkspace();

      aDir = await createProject(
        workspaceDir,
        Pubspec(
          'a',
          dependencies: {'c': HostedDependency(version: VersionConstraint.any)},
        ),
      );

      await createProject(
        workspaceDir,
        Pubspec('b'),
      );

      await createProject(
        workspaceDir,
        Pubspec('c'),
      );

      logger = TestLogger();
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);

      melos = Melos(
        logger: logger,
        config: config,
      );
    });

    test('should run analysis with --fatal-infos flag', () async {
      writeTextFile(
        p.join(aDir.path, 'main.dart'),
        r'''
        void main() {
          for (var i = 0; i < 10; i++) {
            print('hello ${i + 1}');
          }
        }
      ''',
      );

      await melos.analyze(fatalInfos: true);

      expect(
        logger.output.normalizeNewLines(),
        ignoringAnsii(
          '''
\$ melos analyze
  └> dart analyze --fatal-infos
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
a:
Analyzing a...

   info - main.dart:3:13 - Don't invoke 'print' in production code. Try using a logging framework. - avoid_print
   info - main.dart:5:10 - Missing a newline at the end of the file. Try adding a newline at the end of the file. - eol_at_end_of_file

2 issues found.
${'-' * terminalWidth}
b:
Analyzing b...
No issues found!
b: SUCCESS
${'-' * terminalWidth}
c:
Analyzing c...
No issues found!
c: SUCCESS
${'-' * terminalWidth}

\$ melos analyze
  └> dart analyze --fatal-infos
     └> FAILED (in 1 packages)
        └> a (with exit code 1)
''',
        ),
      );
    });

    test('should run analysis with --fatal-warnings flag', () async {
      writeTextFile(
        p.join(aDir.path, 'main.dart'),
        r'''
        void main() {
           var name = "Jessica";
           int age = 28;
           print("Hello, $name!");
        }
      ''',
      );

      await melos.analyze(fatalWarnings: true);

      expect(
        logger.output.normalizeNewLines(),
        ignoringAnsii('''
\$ melos analyze
  └> dart analyze --fatal-warnings
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
a:
Analyzing a...

warning - main.dart:3:16 - The value of the local variable 'age' isn't used. Try removing the variable or using it. - unused_local_variable
   info - main.dart:2:12 - Local variables should be final. Try making the variable final. - prefer_final_locals
   info - main.dart:2:23 - Unnecessary use of double quotes. Try using single quotes unless the string contains single quotes. - prefer_single_quotes
   info - main.dart:3:12 - Local variables should be final. Try making the variable final. - prefer_final_locals
   info - main.dart:3:12 - Unnecessary type annotation on a local variable. Try removing the type annotation. - omit_local_variable_types
   info - main.dart:4:12 - Don't invoke 'print' in production code. Try using a logging framework. - avoid_print
   info - main.dart:4:18 - Unnecessary use of double quotes. Try using single quotes unless the string contains single quotes. - prefer_single_quotes
   info - main.dart:5:10 - Missing a newline at the end of the file. Try adding a newline at the end of the file. - eol_at_end_of_file

8 issues found.
${'-' * terminalWidth}
b:
Analyzing b...
No issues found!
b: SUCCESS
${'-' * terminalWidth}
c:
Analyzing c...
No issues found!
c: SUCCESS
${'-' * terminalWidth}

\$ melos analyze
  └> dart analyze --fatal-warnings
     └> FAILED (in 1 packages)
        └> a (with exit code 2)
'''),
      );
    });

    test('should run analysis with --no-fatal-warnings flag', () async {
      writeTextFile(
        p.join(aDir.path, 'main.dart'),
        r'''
        void main() {
           var name = "Jessica";
           int age = 28;
           print("Hello, $name!");
        }
      ''',
      );

      await melos.analyze(fatalWarnings: false);

      expect(
        logger.output.normalizeNewLines(),
        ignoringAnsii('''
\$ melos analyze
  └> dart analyze --no-fatal-warnings
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
a:
Analyzing a...

warning - main.dart:3:16 - The value of the local variable 'age' isn't used. Try removing the variable or using it. - unused_local_variable
   info - main.dart:2:12 - Local variables should be final. Try making the variable final. - prefer_final_locals
   info - main.dart:2:23 - Unnecessary use of double quotes. Try using single quotes unless the string contains single quotes. - prefer_single_quotes
   info - main.dart:3:12 - Local variables should be final. Try making the variable final. - prefer_final_locals
   info - main.dart:3:12 - Unnecessary type annotation on a local variable. Try removing the type annotation. - omit_local_variable_types
   info - main.dart:4:12 - Don't invoke 'print' in production code. Try using a logging framework. - avoid_print
   info - main.dart:4:18 - Unnecessary use of double quotes. Try using single quotes unless the string contains single quotes. - prefer_single_quotes
   info - main.dart:5:10 - Missing a newline at the end of the file. Try adding a newline at the end of the file. - eol_at_end_of_file

8 issues found.
a: SUCCESS
${'-' * terminalWidth}
b:
Analyzing b...
No issues found!
b: SUCCESS
${'-' * terminalWidth}
c:
Analyzing c...
No issues found!
c: SUCCESS
${'-' * terminalWidth}

\$ melos analyze
  └> dart analyze --no-fatal-warnings
     └> SUCCESS
'''),
      );
    });

    test('should run analysis with --fatal-infos and --fatal-warnings',
        () async {
      writeTextFile(
        p.join(aDir.path, 'main.dart'),
        r'''
        void main() {
           var name = "Jessica";
           int age = 28;
           print("Hello, $name!");
        }
      ''',
      );

      await melos.analyze(fatalInfos: true, fatalWarnings: true);

      expect(
        logger.output.normalizeNewLines(),
        ignoringAnsii('''
\$ melos analyze
  └> dart analyze --fatal-infos --fatal-warnings
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
a:
Analyzing a...

warning - main.dart:3:16 - The value of the local variable 'age' isn't used. Try removing the variable or using it. - unused_local_variable
   info - main.dart:2:12 - Local variables should be final. Try making the variable final. - prefer_final_locals
   info - main.dart:2:23 - Unnecessary use of double quotes. Try using single quotes unless the string contains single quotes. - prefer_single_quotes
   info - main.dart:3:12 - Local variables should be final. Try making the variable final. - prefer_final_locals
   info - main.dart:3:12 - Unnecessary type annotation on a local variable. Try removing the type annotation. - omit_local_variable_types
   info - main.dart:4:12 - Don't invoke 'print' in production code. Try using a logging framework. - avoid_print
   info - main.dart:4:18 - Unnecessary use of double quotes. Try using single quotes unless the string contains single quotes. - prefer_single_quotes
   info - main.dart:5:10 - Missing a newline at the end of the file. Try adding a newline at the end of the file. - eol_at_end_of_file

8 issues found.
${'-' * terminalWidth}
b:
Analyzing b...
No issues found!
b: SUCCESS
${'-' * terminalWidth}
c:
Analyzing c...
No issues found!
c: SUCCESS
${'-' * terminalWidth}

\$ melos analyze
  └> dart analyze --fatal-infos --fatal-warnings
     └> FAILED (in 1 packages)
        └> a (with exit code 2)
'''),
      );
    });

    test('should run analysis with --concurrency flag', () async {
      // when concurrency is set to a number bigger than 1 then
      // the output should appears as the following
      await melos.analyze(concurrency: 2);

      final regex =
          RegExp(r'\$ melos analyze\s+└> dart analyze --concurrency 2');

      expect(regex.hasMatch(logger.output.normalizeNewLines()), isTrue);
    });

    test('should run analysis using flutter & dart', () async {
      final workspaceDir = await createTemporaryWorkspace();

      await createProject(
        workspaceDir,
        Pubspec(
          'a',
          dependencies: {
            'flutter': SdkDependency('flutter'),
          },
        ),
      );

      await createProject(
        workspaceDir,
        Pubspec(
          'b',
          dependencies: {
            'a': HostedDependency(version: VersionConstraint.any),
          },
        ),
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);

      final melos = Melos(
        logger: logger,
        config: config,
      );
      await melos.analyze(concurrency: 2);

      expect(
        logger.output
            .normalizeNewLines()
            .contains('flutter analyze --concurrency 2'),
        isTrue,
      );

      final dartRegex =
          RegExp(r'\$ melos analyze\s+└> dart analyze --concurrency 2');

      expect(dartRegex.hasMatch(logger.output.normalizeNewLines()), isTrue);
    });

    test('should run analysis using flutter', () async {
      final workspaceDir = await createTemporaryWorkspace();

      await createProject(
        workspaceDir,
        Pubspec(
          'a',
          dependencies: {
            'flutter': SdkDependency('flutter'),
          },
        ),
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);

      final melos = Melos(
        logger: logger,
        config: config,
      );
      await melos.analyze(concurrency: 2);

      final flutterRegex =
          RegExp(r'\$ melos analyze\s+└> flutter analyze --concurrency 2');

      expect(flutterRegex.hasMatch(logger.output.normalizeNewLines()), isTrue);
    });

    test('should run analysis using dart', () async {
      final workspaceDir = await createTemporaryWorkspace();
      await createProject(
        workspaceDir,
        Pubspec('a'),
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);

      final melos = Melos(
        logger: logger,
        config: config,
      );
      await melos.analyze(concurrency: 2);

      expect(
        logger.output
            .normalizeNewLines()
            .contains('flutter analyze --concurrency 2'),
        isFalse,
      );

      final dartRegex =
          RegExp(r'\$ melos analyze\s+└> dart analyze --concurrency 2');
      expect(dartRegex.hasMatch(logger.output.normalizeNewLines()), isTrue);
    });

    test('should run analysis with --concurrency 2 flag', () async {
      await melos.analyze(concurrency: 2);

      expect(
        logger.output.normalizeNewLines(),
        ignoringAnsii('''
\$ melos analyze
  └> dart analyze --concurrency 2
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
a:
Analyzing a...
No issues found!
a: SUCCESS
${'-' * terminalWidth}
b:
Analyzing b...
No issues found!
b: SUCCESS
${'-' * terminalWidth}
c:
Analyzing c...
No issues found!
c: SUCCESS
${'-' * terminalWidth}

\$ melos analyze
  └> dart analyze --concurrency 2
     └> SUCCESS
'''),
      );
    });

    test('should run analysis with --concurrency 2 and --fatal-infos flag',
        () async {
      writeTextFile(
        p.join(aDir.path, 'main.dart'),
        r'''
        void main() {
          for (var i = 0; i < 10; i++) {
            print('hello ${i + 1}');
          }
        }
      ''',
      );

      await melos.analyze(concurrency: 2, fatalInfos: true);

      expect(
        logger.output.normalizeNewLines(),
        ignoringAnsii('''
\$ melos analyze
  └> dart analyze --fatal-infos --concurrency 2
     └> RUNNING (in 3 packages)

${'-' * terminalWidth}
a:
Analyzing a...

   info - main.dart:3:13 - Don't invoke 'print' in production code. Try using a logging framework. - avoid_print
   info - main.dart:5:10 - Missing a newline at the end of the file. Try adding a newline at the end of the file. - eol_at_end_of_file

2 issues found.
${'-' * terminalWidth}
b:
Analyzing b...
No issues found!
b: SUCCESS
${'-' * terminalWidth}
c:
Analyzing c...
No issues found!
c: SUCCESS
${'-' * terminalWidth}

\$ melos analyze
  └> dart analyze --fatal-infos --concurrency 2
     └> FAILED (in 1 packages)
        └> a (with exit code 1)
'''),
      );
    });
  });
}
