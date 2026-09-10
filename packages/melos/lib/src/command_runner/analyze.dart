import '../commands/runner.dart';
import '../common/utils.dart';
import 'base.dart';

class AnalyzeCommand extends MelosCommand {
  AnalyzeCommand(super.config) {
    setupPackageFilterParser();
    argParser.addOption('concurrency', defaultsTo: '1', abbr: 'c');
    argParser.addFlag(
      'fatal-infos',
      defaultsTo: true,
      help:
          'Enables or disables treating info-level issues as fatal errors. '
          'Enabled by default for both dart and flutter analyze. '
          'Use --no-fatal-infos to disable.',
    );

    argParser.addFlag(
      'fatal-warnings',
      help:
          'Enables or disables treating warnings as fatal errors. '
          'When enabled, any warning will cause the command to fail.',
    );

    argParser.addFlag(
      'no-pub',
      negatable: false,
      help:
          'Run `flutter analyze` with --no-pub to skip the implicit pub get. '
          'Has no effect on `dart analyze`, which never runs pub get.',
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
    final fatalInfos = argResults!.optional('fatal-infos') as bool?;
    final fatalWarnings = argResults!.optional('fatal-warnings') as bool?;
    final noPub = argResults!.optional('no-pub') as bool?;

    final melos = Melos(logger: logger, config: config);

    return melos.analyze(
      global: global,
      packageFilters: parsePackageFilters(config.path),
      concurrency: concurrencyOption,
      fatalInfos: fatalInfos,
      fatalWarnings: fatalWarnings,
      noPub: noPub,
    );
  }
}
