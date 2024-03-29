import '../commands/runner.dart';
import 'base.dart';

class RunCommand extends MelosCommand {
  RunCommand(super.config) {
    argParser.addFlag(
      'no-select',
      negatable: false,
      help: 'Skips the prompt to select a package (if defined in the script '
          """configuration). Filters defined in the script's "packageFilters" """
          'options will however still be applied.',
    );
  }

  @override
  final String name = 'run';

  @override
  final String description =
      'Run a script by name defined in the workspace melos.yaml config file.';

  @override
  final String invocation = 'melos run <name>';

  @override
  Future<void> run() async {
    final melos = Melos(logger: logger, config: config);

    final noSelect = argResults!['no-select'] as bool;
    final scriptName = argResults!.rest.isEmpty ? null : argResults!.rest.first;
    final extraArgs =
        scriptName != null ? argResults!.rest.skip(1).toList() : <String>[];

    try {
      return await melos.run(
        global: global,
        scriptName: scriptName,
        noSelect: noSelect,
        extraArgs: extraArgs,
      );
    } on NoPackageFoundScriptException catch (err) {
      logger.warning(err.toString(), label: false);
      logger.log(usage);
    }
  }
}
