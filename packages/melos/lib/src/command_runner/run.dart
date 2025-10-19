import '../commands/runner.dart';
import 'base.dart';

class RunCommand extends MelosCommand {
  RunCommand(super.config) {
    argParser.addFlag(
      'no-select',
      negatable: false,
      help:
          'Skips the prompt to select a package (if defined in the script '
          """configuration). Filters defined in the script's "packageFilters" """
          'options will however still be applied.',
    );
    argParser.addFlag(
      'list',
      negatable: false,
      help: 'Lists all scripts defined in the melos.yaml config file.',
    );

    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Lists all scripts defined in the melos.yaml config file with '
          'description in json format.',
    );

    argParser.addFlag(
      'include-private',
      negatable: false,
      help:
          'Ignore the "private" option for scripts to show and be able to run '
          'private scripts',
    );

    argParser.addOption(
      'group',
      abbr: 'g',
      help: 'Filters the scripts by the group they are belonging to.',
    );
  }

  @override
  final String name = 'run';

  @override
  final String description =
      'Run a script by name defined in the workspace pubspec.yaml config file.';

  @override
  final String invocation = 'melos run <name>';

  @override
  Future<void> run() async {
    final melos = Melos(logger: logger, config: config);

    final noSelect = argResults!['no-select'] as bool;
    final scriptName = argResults!.rest.isEmpty ? null : argResults!.rest.first;
    final extraArgs = scriptName != null
        ? argResults!.rest.skip(1).toList()
        : <String>[];
    final listScripts = argResults!['list'] as bool;
    final listScriptsAsJson = argResults!['json'] as bool;
    final includePrivate = argResults!['include-private'] as bool;
    final group = argResults!['group'] as String?;

    try {
      return await melos.run(
        global: global,
        scriptName: scriptName,
        noSelect: noSelect,
        extraArgs: extraArgs,
        listScripts: listScripts,
        listScriptsAsJson: listScriptsAsJson,
        includePrivate: includePrivate,
        group: group,
      );
    } on NoPackageFoundScriptException catch (err) {
      logger.warning(err.toString(), label: false);
      logger.log(usage);
    }
  }
}
