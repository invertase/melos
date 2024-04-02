import '../commands/runner.dart';
import 'base.dart';

class FormatCommand extends MelosCommand {
  FormatCommand(super.config) {
    setupPackageFilterParser();
    argParser.addOption('concurrency', defaultsTo: '1', abbr: 'c');
    argParser.addFlag(
      'set-exit-if-changed',
      negatable: false,
      help: 'Return exit code 1 if there are any formatting changes.',
    );
    argParser.addOption(
      'output',
      help: 'Set where to write formatted output.\n'
          '[json]               Print code and selection as JSON.\n'
          '[none]               Discard output.\n'
          '[show]               Print code to terminal.\n'
          '[write]              Overwrite formatted files on disk.\n',
      abbr: 'o',
    );
    argParser.addOption(
      'line-length',
      help: 'The line length to format the code to.',
    );
  }

  @override
  final String name = 'format';

  @override
  final String description = 'Idiomatically format Dart source code.';

  @override
  Future<void> run() async {
    final setExitIfChanged = argResults?['set-exit-if-changed'] as bool;
    final output = argResults?['output'] as String?;
    final concurrency = int.parse(argResults!['concurrency'] as String);
    final lineLength = switch (argResults?['line-length']) {
      final int length => length,
      _ => null,
    };

    final melos = Melos(logger: logger, config: config);

    return melos.format(
      global: global,
      packageFilters: parsePackageFilters(config.path),
      concurrency: concurrency,
      setExitIfChanged: setExitIfChanged,
      output: output,
      lineLength: lineLength,
    );
  }
}
