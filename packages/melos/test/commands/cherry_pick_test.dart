import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:melos/melos.dart';
import 'package:melos/src/command_runner.dart';
import 'package:melos/src/common/git.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/common/io.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../utils.dart';

void main() {
  group('melos cherry-pick', () {
    late TestLogger logger;
    late Directory workspaceDir;

    setUp(() async {
      logger = TestLogger();
      workspaceDir = await createTemporaryWorkspace(
        workspacePackages: ['a', 'b'],
        configBuilder: _workspaceConfigBuilder,
      );

      await createProject(
        workspaceDir,
        Pubspec('a', version: Version(1, 0, 0)),
      );
      await createProject(
        workspaceDir,
        Pubspec('b', version: Version(1, 0, 0)),
      );
      _writeFile(workspaceDir, 'packages/a/CHANGELOG.md', '## 1.0.0\n');
      _writeFile(workspaceDir, 'CHANGELOG.md', '# Change Log\n');

      await _git(['init', '--initial-branch=main'], workspaceDir);
      await _git(['config', 'user.email', 'test@example.com'], workspaceDir);
      await _git(['config', 'user.name', 'Test'], workspaceDir);
      await _git(['config', 'commit.gpgsign', 'false'], workspaceDir);
      // Git for Windows converts line endings when it checks out files by
      // default, which the expected file contents do not account for.
      await _git(['config', 'core.autocrlf', 'false'], workspaceDir);
      await _commitAll(workspaceDir, 'chore: initial commit');
      await _git(['branch', 'hot-fix'], workspaceDir);
    });

    Future<void> cherryPick(
      List<String> commits, {
      bool recordOrigin = true,
    }) async {
      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      await Melos(logger: logger, config: config).cherryPick(
        commits: commits,
        recordOrigin: recordOrigin,
      );
    }

    test('picks a commit and records where it originates from', () async {
      _writeFile(workspaceDir, 'packages/a/lib/fix.dart', '// A fix.\n');
      await _commitAll(workspaceDir, 'fix: a bug');
      final fixId = await _commitId(workspaceDir, 'HEAD');
      await _git(['checkout', 'hot-fix'], workspaceDir);

      await cherryPick([fixId]);

      expect(_fileExists(workspaceDir, 'packages/a/lib/fix.dart'), isTrue);
      expect(
        await _message(workspaceDir, 'HEAD'),
        'fix: a bug\n\n(cherry picked from commit $fixId)',
      );
      expect(await _commitCount(workspaceDir), 2);
    });

    test('does not record the origin with recordOrigin turned off', () async {
      _writeFile(workspaceDir, 'packages/a/lib/fix.dart', '// A fix.\n');
      await _commitAll(workspaceDir, 'fix: a bug');
      final fixId = await _commitId(workspaceDir, 'HEAD');
      await _git(['checkout', 'hot-fix'], workspaceDir);

      await cherryPick([fixId], recordOrigin: false);

      expect(await _message(workspaceDir, 'HEAD'), 'fix: a bug');
    });

    test('leaves out the changelog and version changes of a commit', () async {
      _writeFile(workspaceDir, 'packages/a/lib/fix.dart', '// A fix.\n');
      _writeFile(
        workspaceDir,
        'packages/a/CHANGELOG.md',
        '## 1.0.1\n\n - **FIX**: a bug.\n\n## 1.0.0\n',
      );
      _writeFile(
        workspaceDir,
        'CHANGELOG.md',
        '# Change Log\n\n## 2026-01-01\n',
      );
      _setVersion(workspaceDir, 'a', '1.0.1');
      await _commitAll(workspaceDir, 'fix: a bug');
      final fixId = await _commitId(workspaceDir, 'HEAD');
      await _git(['checkout', 'hot-fix'], workspaceDir);

      await cherryPick([fixId]);

      expect(_fileExists(workspaceDir, 'packages/a/lib/fix.dart'), isTrue);
      expect(
        _readFile(workspaceDir, 'packages/a/CHANGELOG.md'),
        '## 1.0.0\n',
      );
      expect(_readFile(workspaceDir, 'CHANGELOG.md'), '# Change Log\n');
      expect(_version(workspaceDir, 'a'), '1.0.0');
      expect(await _changedFiles(workspaceDir, 'HEAD'), [
        'packages/a/lib/fix.dart',
      ]);
      expect(await _status(workspaceDir), isEmpty);
    });

    test('keeps the other changes that a commit makes to a pubspec', () async {
      final pubspec = _readFile(workspaceDir, 'packages/a/pubspec.yaml');
      _writeFile(
        workspaceDir,
        'packages/a/pubspec.yaml',
        '${pubspec.trimRight()}\ndescription: A described package.\n',
      );
      _setVersion(workspaceDir, 'a', '2.0.0');
      await _commitAll(workspaceDir, 'feat: describe a');
      final featureId = await _commitId(workspaceDir, 'HEAD');
      await _git(['checkout', 'hot-fix'], workspaceDir);

      await cherryPick([featureId]);

      expect(_version(workspaceDir, 'a'), '1.0.0');
      expect(
        _readFile(workspaceDir, 'packages/a/pubspec.yaml'),
        contains('description: A described package.'),
      );
    });

    test('resolves changelog conflicts with the changelog of the current '
        'branch', () async {
      _writeFile(
        workspaceDir,
        'packages/a/CHANGELOG.md',
        '## 2.0.0\n\n - **FEAT**: a feature.\n\n## 1.0.0\n',
      );
      await _commitAll(workspaceDir, 'chore(release): publish 2.0.0');
      _writeFile(workspaceDir, 'packages/a/lib/fix.dart', '// A fix.\n');
      _writeFile(
        workspaceDir,
        'packages/a/CHANGELOG.md',
        '## 2.0.1\n\n - **FIX**: a bug.\n\n## 2.0.0\n\n - **FEAT**: a '
            'feature.\n\n## 1.0.0\n',
      );
      await _commitAll(workspaceDir, 'fix: a bug');
      final fixId = await _commitId(workspaceDir, 'HEAD');

      await _git(['checkout', 'hot-fix'], workspaceDir);
      _writeFile(
        workspaceDir,
        'packages/a/CHANGELOG.md',
        '## 1.0.1\n\n - **FIX**: something else.\n\n## 1.0.0\n',
      );
      await _commitAll(workspaceDir, 'chore(release): publish 1.0.1');

      await cherryPick([fixId]);

      expect(_fileExists(workspaceDir, 'packages/a/lib/fix.dart'), isTrue);
      expect(
        _readFile(workspaceDir, 'packages/a/CHANGELOG.md'),
        '## 1.0.1\n\n - **FIX**: something else.\n\n## 1.0.0\n',
      );
      expect(
        await _message(workspaceDir, 'HEAD'),
        'fix: a bug\n\n(cherry picked from commit $fixId)',
      );
      expect(await _status(workspaceDir), isEmpty);
    });

    test('skips commits that only contain release changes', () async {
      _writeFile(
        workspaceDir,
        'packages/a/CHANGELOG.md',
        '## 1.1.0\n\n - **FEAT**: a feature.\n\n## 1.0.0\n',
      );
      _setVersion(workspaceDir, 'a', '1.1.0');
      await _commitAll(workspaceDir, 'chore(release): publish packages');
      final releaseId = await _commitId(workspaceDir, 'HEAD');
      await _git(['checkout', 'hot-fix'], workspaceDir);

      await cherryPick([releaseId]);

      expect(await _commitCount(workspaceDir), 1);
      expect(_version(workspaceDir, 'a'), '1.0.0');
      expect(await _status(workspaceDir), isEmpty);
      expect(
        logger.output,
        contains('contains no changes besides release changes'),
      );
    });

    test('resolves version conflicts with the version of the current '
        'branch', () async {
      _setVersion(workspaceDir, 'a', '2.0.0');
      await _commitAll(workspaceDir, 'chore(release): publish 2.0.0');
      final start = await _commitId(workspaceDir, 'HEAD');
      final pubspec = _readFile(workspaceDir, 'packages/a/pubspec.yaml');
      _writeFile(
        workspaceDir,
        'packages/a/pubspec.yaml',
        '${pubspec.trimRight()}\ndescription: A described package.\n',
      );
      _setVersion(workspaceDir, 'a', '2.1.0');
      await _commitAll(workspaceDir, 'feat: describe a');
      _setVersion(workspaceDir, 'a', '2.1.1');
      await _commitAll(workspaceDir, 'chore(release): publish 2.1.1');
      await _git(['checkout', 'hot-fix'], workspaceDir);

      await cherryPick(['$start..main']);

      expect(await _commitCount(workspaceDir), 2);
      expect(await _subject(workspaceDir, 'HEAD'), 'feat: describe a');
      expect(_version(workspaceDir, 'a'), '1.0.0');
      expect(
        _readFile(workspaceDir, 'packages/a/pubspec.yaml'),
        contains('description: A described package.'),
      );
      expect(await _status(workspaceDir), isEmpty);
    });

    test('keeps the lines of a message that start with a comment character '
        'when resolving conflicts', () async {
      _writeFile(workspaceDir, 'packages/a/lib/fix.dart', '// A fix.\n');
      _writeFile(workspaceDir, 'packages/a/CHANGELOG.md', '## 1.0.1\n');
      await _commitAll(workspaceDir, 'fix: a bug\n\n#123 is fixed by this.');
      final fixId = await _commitId(workspaceDir, 'HEAD');
      await _git(['checkout', 'hot-fix'], workspaceDir);
      _writeFile(workspaceDir, 'packages/a/CHANGELOG.md', '## 1.0.0+1\n');
      await _commitAll(workspaceDir, 'chore(release): publish 1.0.0+1');

      await cherryPick([fixId]);

      expect(
        await _message(workspaceDir, 'HEAD'),
        'fix: a bug\n\n#123 is fixed by this.\n\n'
        '(cherry picked from commit $fixId)',
      );
    });

    test('skips release commits that update the constraints of '
        'dependents', () async {
      _setDependency(workspaceDir, 'b', 'a', '^1.0.0');
      await _commitAll(workspaceDir, 'chore: let b depend on a');
      await _git(['branch', '--force', 'hot-fix'], workspaceDir);
      _writeFile(
        workspaceDir,
        'packages/a/CHANGELOG.md',
        '## 1.1.0\n\n - **FEAT**: a feature.\n\n## 1.0.0\n',
      );
      _setVersion(workspaceDir, 'a', '1.1.0');
      _setVersion(workspaceDir, 'b', '1.0.1');
      _setDependency(workspaceDir, 'b', 'a', '^1.1.0');
      await _commitAll(workspaceDir, 'chore(release): publish packages');
      final releaseId = await _commitId(workspaceDir, 'HEAD');
      await _git(['checkout', 'hot-fix'], workspaceDir);

      await cherryPick([releaseId]);

      expect(await _commitCount(workspaceDir), 2);
      expect(_version(workspaceDir, 'b'), '1.0.0');
      expect(
        _readFile(workspaceDir, 'packages/b/pubspec.yaml'),
        contains('a: ^1.0.0'),
      );
      expect(await _status(workspaceDir), isEmpty);
    });

    test('skips commits whose changes are already on the branch', () async {
      _writeFile(workspaceDir, 'packages/a/lib/fix.dart', '// A fix.\n');
      await _commitAll(workspaceDir, 'fix: a bug');
      final fixId = await _commitId(workspaceDir, 'HEAD');
      await _git(['checkout', 'hot-fix'], workspaceDir);
      await cherryPick([fixId]);

      await cherryPick([fixId]);

      expect(await _commitCount(workspaceDir), 2);
      expect(await _status(workspaceDir), isEmpty);
      expect(logger.output, contains('are already on this branch'));
    });

    test('picks a commit once when several revisions refer to it', () async {
      final start = await _commitId(workspaceDir, 'HEAD');
      _writeFile(workspaceDir, 'packages/a/lib/fix.dart', '// A fix.\n');
      await _commitAll(workspaceDir, 'fix: a bug');
      final fixId = await _commitId(workspaceDir, 'HEAD');
      await _git(['checkout', 'hot-fix'], workspaceDir);

      await cherryPick(['$start..main', fixId]);

      expect(await _commitCount(workspaceDir), 2);
      expect(logger.output, isNot(contains('Skipped')));
    });

    test('throws for revisions that exclude commits', () async {
      await expectLater(
        cherryPick(['^main']),
        throwsA(
          isA<CherryPickException>().having(
            (exception) => exception.message,
            'message',
            contains('main..<end-commit>'),
          ),
        ),
      );
    });

    test('lets melos version release the picked commits from a hot-fix '
        'branch', () async {
      await _git(['tag', 'a-v1.0.0'], workspaceDir);
      _writeFile(workspaceDir, 'packages/a/lib/feature.dart', '// Feature.\n');
      await _commitAll(workspaceDir, 'feat: a feature');
      _writeFile(workspaceDir, 'packages/a/lib/fix.dart', '// A fix.\n');
      await _commitAll(workspaceDir, 'fix: a bug');
      final fixId = await _commitId(workspaceDir, 'HEAD');
      _writeFile(
        workspaceDir,
        'packages/a/CHANGELOG.md',
        '## 1.1.0\n\n - **FIX**: a bug.\n - **FEAT**: a feature.\n\n'
            '## 1.0.0\n',
      );
      _setVersion(workspaceDir, 'a', '1.1.0');
      await _commitAll(workspaceDir, 'chore(release): publish packages');
      final releaseId = await _commitId(workspaceDir, 'HEAD');
      await _git(['tag', 'a-v1.1.0'], workspaceDir);
      await _git(['checkout', 'hot-fix'], workspaceDir);

      await cherryPick([fixId, releaseId]);

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir);
      await Melos(logger: logger, config: config).version(
        versionPrivatePackages: true,
        gitCommit: false,
        gitTag: false,
        force: true,
      );

      expect(_version(workspaceDir, 'a'), '1.0.1');
      expect(
        _readFile(workspaceDir, 'packages/a/CHANGELOG.md'),
        '## 1.0.1\n\n - **FIX**: a bug.\n\n## 1.0.0\n',
      );
      expect(_version(workspaceDir, 'b'), '1.0.0');
    });

    test('picks the commits of a range from oldest to newest', () async {
      final start = await _commitId(workspaceDir, 'HEAD');
      _writeFile(workspaceDir, 'packages/a/lib/first.dart', '// First.\n');
      await _commitAll(workspaceDir, 'fix: first');
      _writeFile(workspaceDir, 'packages/b/lib/second.dart', '// Second.\n');
      await _commitAll(workspaceDir, 'fix: second');
      await _git(['checkout', 'hot-fix'], workspaceDir);

      await cherryPick(['$start..main']);

      expect(await _subject(workspaceDir, 'HEAD~1'), 'fix: first');
      expect(await _subject(workspaceDir, 'HEAD'), 'fix: second');
    });

    test('picks a range that leaves out the start commit', () async {
      _writeFile(workspaceDir, 'packages/a/lib/first.dart', '// First.\n');
      await _commitAll(workspaceDir, 'fix: first');
      await _git(['checkout', 'hot-fix'], workspaceDir);

      await cherryPick(['..main']);

      expect(await _subject(workspaceDir, 'HEAD'), 'fix: first');
      expect(await _commitCount(workspaceDir), 2);
    });

    test('stops at conflicts that are not in release files', () async {
      _writeFile(workspaceDir, 'packages/a/lib/fix.dart', '// From main.\n');
      _writeFile(
        workspaceDir,
        'packages/a/CHANGELOG.md',
        '## 1.0.1\n\n - **FIX**: a bug.\n\n## 1.0.0\n',
      );
      await _commitAll(workspaceDir, 'fix: a bug');
      final fixId = await _commitId(workspaceDir, 'HEAD');
      _writeFile(workspaceDir, 'packages/b/lib/other.dart', '// Other.\n');
      await _commitAll(workspaceDir, 'fix: another bug');
      final otherId = await _commitId(workspaceDir, 'HEAD');

      await _git(['checkout', 'hot-fix'], workspaceDir);
      _writeFile(workspaceDir, 'packages/a/lib/fix.dart', '// From hot-fix.\n');
      await _commitAll(workspaceDir, 'fix: a different fix');

      await expectLater(
        cherryPick([fixId, otherId]),
        throwsA(
          isA<CherryPickConflictException>()
              .having(
                (exception) => exception.conflictedFiles,
                'conflictedFiles',
                ['packages/a/lib/fix.dart'],
              )
              .having(
                (exception) => exception.remainingCommitIds,
                'remainingCommitIds',
                [otherId],
              ),
        ),
      );

      expect(
        _readFile(workspaceDir, 'packages/a/CHANGELOG.md'),
        '## 1.0.0\n',
      );
      expect(await _status(workspaceDir), ['AA packages/a/lib/fix.dart']);
    });

    test('throws when the repository has uncommitted changes', () async {
      _writeFile(workspaceDir, 'packages/a/lib/fix.dart', '// A fix.\n');
      await _commitAll(workspaceDir, 'fix: a bug');
      final fixId = await _commitId(workspaceDir, 'HEAD');
      await _git(['checkout', 'hot-fix'], workspaceDir);
      _setVersion(workspaceDir, 'b', '1.0.1');

      await expectLater(
        cherryPick([fixId]),
        throwsA(isA<CherryPickException>()),
      );
      expect(await _commitCount(workspaceDir), 1);
    });

    group('command line', () {
      late MelosCommandRunner runner;

      setUp(() async {
        runner = MelosCommandRunner(
          await MelosWorkspaceConfig.fromWorkspaceRoot(workspaceDir),
        );
      });

      test('picks the given commits', () async {
        _writeFile(workspaceDir, 'packages/a/lib/fix.dart', '// A fix.\n');
        await _commitAll(workspaceDir, 'fix: a bug');
        await _git(['checkout', 'hot-fix'], workspaceDir);

        await runner.run(['cherry-pick', 'main', '--no-record-origin']);

        expect(await _message(workspaceDir, 'HEAD'), 'fix: a bug');
      });

      test('requires at least one commit', () async {
        await expectLater(
          runner.run(['cherry-pick']),
          throwsA(isA<UsageException>()),
        );
      });

      test('requires the mainline to be a parent number', () async {
        await expectLater(
          runner.run(['cherry-pick', 'main', '--mainline', '0']),
          throwsA(isA<UsageException>()),
        );
      });
    });

    test('throws when a revision does not exist', () async {
      await expectLater(
        cherryPick(['does-not-exist']),
        throwsA(
          isA<CherryPickException>().having(
            (exception) => exception.message,
            'message',
            contains('does-not-exist'),
          ),
        ),
      );
    });
  });
}

MelosWorkspaceConfig _workspaceConfigBuilder(String path) {
  return MelosWorkspaceConfig(
    path: path,
    name: 'test_workspace',
    packages: [
      createGlob('packages/**', currentDirectoryPath: path),
    ],
    commands: const CommandConfigs(
      version: VersionCommandConfigs(fetchTags: false),
    ),
  );
}

Future<String> _git(List<String> arguments, Directory workspaceDir) async {
  final result = await gitExecuteCommand(
    arguments: arguments,
    workingDirectory: workspaceDir.path,
    logger: TestLogger().toMelosLogger(),
  );
  return (result.stdout as String).trim();
}

Future<List<String>> _gitLines(
  List<String> arguments,
  Directory workspaceDir,
) async {
  final output = await _git(arguments, workspaceDir);
  return output.split('\n').where((line) => line.isNotEmpty).toList();
}

Future<void> _commitAll(Directory workspaceDir, String message) async {
  await _git(['add', '.'], workspaceDir);
  await _git(['commit', '--no-gpg-sign', '-m', message], workspaceDir);
}

Future<String> _commitId(Directory workspaceDir, String revision) =>
    _git(['rev-parse', revision], workspaceDir);

Future<String> _message(Directory workspaceDir, String revision) =>
    _git(['show', '--no-patch', '--format=%B', revision], workspaceDir);

Future<String> _subject(Directory workspaceDir, String revision) =>
    _git(['show', '--no-patch', '--format=%s', revision], workspaceDir);

Future<int> _commitCount(Directory workspaceDir) async =>
    int.parse(await _git(['rev-list', '--count', 'HEAD'], workspaceDir));

Future<List<String>> _changedFiles(Directory workspaceDir, String revision) =>
    _gitLines([
      'diff',
      '--name-only',
      '$revision~1',
      revision,
    ], workspaceDir);

Future<List<String>> _status(Directory workspaceDir) => _gitLines([
  'status',
  '--porcelain',
  '--untracked-files=no',
], workspaceDir);

String _path(Directory workspaceDir, String file) =>
    p.joinAll([workspaceDir.path, ...p.posix.split(file)]);

void _writeFile(Directory workspaceDir, String file, String contents) =>
    writeTextFile(_path(workspaceDir, file), contents, recursive: true);

String _readFile(Directory workspaceDir, String file) =>
    readTextFile(_path(workspaceDir, file));

bool _fileExists(Directory workspaceDir, String file) =>
    fileExists(_path(workspaceDir, file));

String? _version(Directory workspaceDir, String packageName) => RegExp(
  r'^version: (.*)$',
  multiLine: true,
).firstMatch(_readFile(workspaceDir, 'packages/$packageName/pubspec.yaml'))?[1];

void _setDependency(
  Directory workspaceDir,
  String packageName,
  String dependencyName,
  String constraint,
) {
  final file = 'packages/$packageName/pubspec.yaml';
  final editor = YamlEditor(_readFile(workspaceDir, file));
  final dependencies = editor.parseAt(
    ['dependencies'],
    orElse: () => wrapAsYamlNode(null),
  );
  if (dependencies.value == null) {
    editor.update(['dependencies'], {dependencyName: constraint});
  } else {
    editor.update(['dependencies', dependencyName], constraint);
  }
  _writeFile(workspaceDir, file, editor.toString());
}

void _setVersion(Directory workspaceDir, String packageName, String version) {
  final file = 'packages/$packageName/pubspec.yaml';
  _writeFile(
    workspaceDir,
    file,
    _readFile(workspaceDir, file).replaceFirst(
      RegExp(r'^version:.*$', multiLine: true),
      'version: $version',
    ),
  );
}
