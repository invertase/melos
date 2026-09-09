import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:melos/melos.dart';
import 'package:melos/src/command_runner.dart';
import 'package:melos/src/common/git.dart';
import 'package:melos/src/common/io.dart';
import 'package:melos/src/common/utils.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

import '../matchers.dart';
import '../utils.dart';

void main() {
  group('melos changed', () {
    late TestLogger logger;
    late Directory workspaceDir;

    setUp(() async {
      logger = TestLogger();
      workspaceDir = await createTemporaryWorkspace(
        workspacePackages: ['a', 'b'],
      );

      await createProject(
        workspaceDir,
        Pubspec('a', version: Version(1, 0, 0)),
      );
      await createProject(
        workspaceDir,
        Pubspec(
          'b',
          version: Version(1, 0, 0),
          dependencies: {'a': HostedDependency(version: VersionConstraint.any)},
        ),
      );

      await _git(['init'], workspaceDir);
      await _git(['config', 'user.email', 'test@example.com'], workspaceDir);
      await _git(['config', 'user.name', 'Test'], workspaceDir);
      await _commitAll(workspaceDir, 'chore: initial commit');
    });

    Future<void> listChanged({
      String? ref,
      bool includeDependents = false,
    }) async {
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      await Melos(logger: logger, config: config).list(
        packageFilters: PackageFilters(
          diff: ref ?? gitDiffSinceLatestTag,
          includeDependents: includeDependents,
        ),
      );
    }

    test(
      'lists packages that changed since their latest release tag',
      () async {
        await _tag(workspaceDir, 'a-v1.0.0');
        await _tag(workspaceDir, 'b-v1.0.0');
        _changePackage(workspaceDir, 'a');
        await _commitAll(workspaceDir, 'feat: change a');

        await listChanged();

        expect(_output(logger), ignoringAnsii('a\n'));
      },
    );

    test('lists no packages when nothing changed since the latest release '
        'tag', () async {
      await _tag(workspaceDir, 'a-v1.0.0');
      await _tag(workspaceDir, 'b-v1.0.0');

      await listChanged();

      expect(
        _output(logger),
        ignoringAnsii(contains('No packages were found')),
      );
    });

    test('lists packages that have never been released', () async {
      _changePackage(workspaceDir, 'a');
      await _commitAll(workspaceDir, 'feat: change a');

      await listChanged();

      expect(_output(logger), ignoringAnsii('a\nb\n'));
    });

    test(
      'compares a prerelease version against its latest stable tag',
      () async {
        // Package `a` is in a prerelease cycle without a prerelease tag yet, so
        // its stable tag is the latest release to compare against.
        _setVersion(workspaceDir, 'a', '1.1.0-dev.1');
        await _commitAll(workspaceDir, 'chore: start the prerelease of a');
        await _tag(workspaceDir, 'a-v1.0.0');
        await _tag(workspaceDir, 'b-v1.0.0');

        await listChanged();

        expect(
          _output(logger),
          ignoringAnsii(contains('No packages were found')),
        );
      },
    );

    test('throws when the given ref does not exist', () {
      expect(
        listChanged(ref: 'not-a-ref'),
        throwsA(isA<InvalidPackageFiltersException>()),
      );
    });

    test('lists packages that changed since a given ref', () async {
      await _tag(workspaceDir, 'a-v1.0.0');
      await _tag(workspaceDir, 'b-v1.0.0');
      _changePackage(workspaceDir, 'a');
      await _commitAll(workspaceDir, 'feat: change a');
      _changePackage(workspaceDir, 'b');
      await _commitAll(workspaceDir, 'feat: change b');

      await listChanged(ref: 'HEAD~1');

      expect(_output(logger), ignoringAnsii('b\n'));
    });

    test('lists packages that changed within a range of commits', () async {
      _changePackage(workspaceDir, 'a');
      await _commitAll(workspaceDir, 'feat: change a');
      _changePackage(workspaceDir, 'b');
      await _commitAll(workspaceDir, 'feat: change b');

      await listChanged(ref: 'HEAD~2..HEAD~1');

      expect(_output(logger), ignoringAnsii('a\n'));
    });

    test('lists the dependents of the changed packages with '
        'includeDependents', () async {
      await _tag(workspaceDir, 'a-v1.0.0');
      await _tag(workspaceDir, 'b-v1.0.0');
      _changePackage(workspaceDir, 'a');
      await _commitAll(workspaceDir, 'feat: change a');

      await listChanged(includeDependents: true);

      expect(_output(logger), ignoringAnsii('a\nb\n'));
    });

    group('command line', () {
      late MelosCommandRunner runner;

      setUp(() async {
        runner = MelosCommandRunner(
          await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir),
        );
      });

      test('supports the package filtering options, except --diff', () {
        final argParser = runner.commands['changed']!.argParser;

        expect(argParser.options, contains(filterOptionScope));
        expect(argParser.options, contains(filterOptionIncludeDependents));
        expect(argParser.options, isNot(contains(filterOptionDiff)));
      });

      test('takes at most one commit or tag', () {
        expect(
          runner.run(['changed', 'HEAD~2', 'HEAD~1']),
          throwsA(isA<UsageException>()),
        );
      });
    });
  });
}

/// The logged output, without the trace logs of the executed git commands.
String _output(TestLogger logger) => logger.output
    .split('\n')
    .where((line) => !line.startsWith('t-'))
    .join('\n');

Future<void> _git(List<String> arguments, Directory workspaceDir) =>
    gitExecuteCommand(
      arguments: arguments,
      workingDirectory: workspaceDir.path,
      logger: TestLogger().toMelosLogger(),
    );

Future<void> _commitAll(Directory workspaceDir, String message) async {
  await _git(['add', '.'], workspaceDir);
  await _git(['commit', '--no-gpg-sign', '-m', message], workspaceDir);
}

Future<void> _tag(Directory workspaceDir, String tag) =>
    _git(['tag', tag], workspaceDir);

void _setVersion(Directory workspaceDir, String packageName, String version) {
  final pubspec = p.join(
    workspaceDir.path,
    'packages',
    packageName,
    'pubspec.yaml',
  );
  writeTextFile(
    pubspec,
    readTextFile(pubspec).replaceFirst(
      RegExp(r'^version:.*$', multiLine: true),
      'version: $version',
    ),
  );
}

void _changePackage(Directory workspaceDir, String packageName) {
  writeTextFile(
    p.join(workspaceDir.path, 'packages', packageName, 'lib', 'change.dart'),
    '// A change in $packageName.\n',
    recursive: true,
  );
}
