import 'package:args/command_runner.dart';
import 'package:melos/melos.dart';
import 'package:melos/src/command_runner.dart';
import 'package:melos/src/command_runner/base.dart';
import 'package:melos/src/common/glob.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('CommandRunner', () {
    test('adds hidden script commands', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'test_script1': Script(name: 'test_script1', run: ''),
            'test_script2': Script(name: 'test_script2', run: ''),
          }),
        ),
        workspacePackages: [],
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
        workspaceDir,
      );
      final runner = MelosCommandRunner(config);

      expect(
        runner.commands.keys,
        containsAll(<String>['test_script1', 'test_script2']),
      );

      final command = runner.commands['test_script1'];
      expect(command, isNotNull);
      expect(command!.hidden, isTrue);
    });

    test('custom scripts override built-in commands', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'format': Script(name: 'format', run: 'echo "custom format"'),
          }),
        ),
        workspacePackages: [],
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
        workspaceDir,
      );
      final runner = MelosCommandRunner(config);

      final command = runner.commands['format'];
      expect(command, isNotNull);
      // The command should be hidden (custom script behavior)
      expect(command!.hidden, isTrue);
    });

    test('custom analyze script overrides built-in analyze command', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'analyze': Script(
              name: 'analyze',
              run: 'echo "custom analyze ran"',
            ),
          }),
        ),
        workspacePackages: [],
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
        workspaceDir,
      );

      // Structural check: the registered command for 'analyze' should be
      // the hidden ScriptCommand, not the built-in AnalyzeCommand.
      final runner = MelosCommandRunner(config);
      final command = runner.commands['analyze'];
      expect(command, isNotNull);
      expect(command!.hidden, isTrue);

      // Behavioral check: actually running the 'analyze' script should
      // execute the user's custom command, not the built-in
      // AnalyzeCommand's logic.
      final logger = TestLogger();
      final melos = Melos(logger: logger, config: config);

      await melos.run(scriptName: 'analyze', noSelect: true);

      expect(
        logger.output.normalizeLines(),
        contains('custom analyze ran'),
      );
      // The built-in AnalyzeCommand's own output format should never
      // appear.
      expect(
        logger.output.normalizeLines(),
        isNot(contains(r'$ melos analyze')),
      );
    });

    test('custom test script overrides built-in test command', () async {
      final workspaceDir = await createTemporaryWorkspace(
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_package',
          packages: [
            createGlob('packages/**', currentDirectoryPath: path),
          ],
          scripts: const Scripts({
            'test': Script(name: 'test', run: 'echo "custom test ran"'),
          }),
        ),
        workspacePackages: [],
      );

      final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
        workspaceDir,
      );

      // Structural check: the registered command for 'test' should be the
      // hidden ScriptCommand, not the built-in TestCommand.
      final runner = MelosCommandRunner(config);
      final command = runner.commands['test'];
      expect(command, isNotNull);
      expect(command!.hidden, isTrue);

      // Behavioral check: actually running the 'test' script should execute
      // the user's custom command, not the built-in TestCommand's logic.
      final logger = TestLogger();
      final melos = Melos(logger: logger, config: config);

      await melos.run(scriptName: 'test', noSelect: true);

      expect(
        logger.output.normalizeLines(),
        contains('custom test ran'),
      );
      // The built-in TestCommand's own output format should never appear.
      expect(
        logger.output.normalizeLines(),
        isNot(contains('No packages with a test/ directory found.')),
      );
    });
  });

  group('--post-filter', () {
    Future<PackageFilters> parseFilters(List<String> arguments) async {
      final command = _FilterCommand(MelosWorkspaceConfig.empty());
      final runner = CommandRunner<void>('melos', '')..addCommand(command);
      await runner.run([command.name, ...arguments]);
      return command.filters;
    }

    test('is not set by default', () async {
      final filters = await parseFilters(['--scope=a']);

      expect(filters.postFilters, isNull);
    });

    test('parses the values as filters', () async {
      final filters = await parseFilters([
        '--scope=a',
        '--include-dependencies',
        '--post-filter=depends-on=build_runner',
        '--post-filter',
        'dir-exists=test',
        '--post-filter=no-flutter',
      ]);

      expect(filters.includeDependencies, isTrue);
      expect(filters.dependsOn, isEmpty);
      expect(
        filters.postFilters,
        const PackageFilters(
          dependsOn: ['build_runner'],
          dirExists: ['test'],
          flutter: false,
        ),
      );
    });

    test('supports comma separated values', () async {
      final filters = await parseFilters(['--post-filter=depends-on=a,b']);

      expect(filters.postFilters, const PackageFilters(dependsOn: ['a', 'b']));
    });

    for (final filter in [
      'include-dependents',
      'include-dependencies',
      'post-filter=scope=a',
      'unknown',
    ]) {
      test('throws for the value $filter', () {
        expect(
          parseFilters(['--post-filter=$filter']),
          throwsA(isA<UsageException>()),
        );
      });
    }
  });
}

class _FilterCommand extends MelosCommand {
  _FilterCommand(super.config) {
    setupPackageFilterParser();
  }

  late PackageFilters filters;

  @override
  String get name => 'filter';

  @override
  String get description => 'Parses the package filters.';

  @override
  void run() => filters = parsePackageFilters(config.path);
}
