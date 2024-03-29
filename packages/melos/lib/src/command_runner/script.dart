import '../commands/runner.dart';
import '../workspace_configs.dart';
import 'base.dart';

class ScriptCommand extends MelosCommand {
  ScriptCommand._(
    super.config, {
    required this.scripts,
  }) : assert(scripts.isNotEmpty) {
    argParser.addFlag(
      'no-select',
      negatable: false,
      help: 'Skips the prompt to select a package (if defined in the script '
          """configuration). Filters defined in the script's "packageFilters" """
          'options will however still be applied.',
    );
  }

  static ScriptCommand? fromConfig(
    MelosWorkspaceConfig config, {
    Iterable<String> exclude = const <String>[],
  }) {
    final scripts = config.scripts.keys.toSet();
    scripts.removeAll(exclude);
    if (scripts.isEmpty) {
      return null;
    }
    return ScriptCommand._(config, scripts: scripts);
  }

  final Set<String> scripts;

  @override
  String get name => scripts.first;

  @override
  List<String> get aliases => scripts.skip(1).toList();

  @override
  String get description =>
      'Run scripts by name defined in the workspace melos.yaml config file.';

  @override
  final String invocation = 'melos <script>';

  @override
  bool get hidden => true;

  @override
  Future<void> run() async {
    final melos = Melos(logger: logger, config: config);

    final scriptName = argResults!.name;
    final noSelect = argResults!['no-select'] as bool;

    try {
      return await melos.run(
        global: global,
        scriptName: scriptName,
        noSelect: noSelect,
        extraArgs: argResults!.rest,
      );
    } on NoPackageFoundScriptException catch (err) {
      logger.warning(err.toString(), label: false);
      logger.log(usage);
    }
  }
}
