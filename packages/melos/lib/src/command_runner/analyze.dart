import '../commands/runner.dart';
import '../common/utils.dart';
import 'base.dart';

class AnalyzeCommand extends MelosCommand {
  AnalyzeCommand(super.config) {
    setupPackageFilterParser();
    argParser.addOption('concurrency', defaultsTo: '1', abbr: 'c');
    argParser.addFlag(
      'fatal-infos',
      negatable: false,
      help: 'Enables treating info-lever issues as fatal errors, '
          'stopping the process if any are encountered.',
    );

    argParser.addFlag(
      'fatal-warnings',
      help: 'Enables or disables treating warnings as fatal errors. '
          'When enabled, any warning will cause the command to fail.',
    );
  }

  @override
  final String name = 'analyze';

  @override
  final String description =
      'Analyzes all packages in your project for potential issues '
      'in a single run. Optionally configure severity levels. '
      'Supports all package filtering options.';

  @override
  Future<void> run() async {
    final fatalInfos = argResults?['fatal-infos'] as bool;
    final fatalWarnings = argResults!.optional('fatal-warnings') as bool?;
    final concurrency = int.parse(argResults!['concurrency'] as String);

    final melos = Melos(logger: logger, config: config);

    return melos.analyze(
      global: global,
      packageFilters: parsePackageFilters(config.path),
      concurrency: concurrency,
      fatalInfos: fatalInfos,
      fatalWarnings: fatalWarnings,
    );
  }
}
