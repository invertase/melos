import '../commands/runner.dart';
import 'base.dart';

class TestCommand extends MelosCommand {
  TestCommand(super.config) {
    setupPackageFilterParser();
    argParser.addOption('concurrency', defaultsTo: '1', abbr: 'c');
    argParser.addFlag(
      'no-pub',
      negatable: false,
      help:
          'Run `flutter test` with --no-pub to skip the implicit pub get. '
          'Has no effect on `dart test`, which does not support the flag.',
    );
  }

  @override
  final String name = 'test';

  @override
  final String description =
      'Run `flutter test`/`dart test` for all packages in the workspace '
      'that have a test/ directory, in a single run. '
      'Supports all package filtering options.';

  @override
  Future<void> run() async {
    final concurrency = int.parse(argResults!['concurrency'] as String);
    final noPub = argResults!['no-pub'] as bool;

    final melos = Melos(logger: logger, config: config);

    return melos.test(
      global: global,
      packageFilters: parsePackageFilters(config.path),
      concurrency: concurrency,
      noPub: noPub,
    );
  }
}
