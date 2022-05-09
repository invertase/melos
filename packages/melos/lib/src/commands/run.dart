part of 'runner.dart';

mixin _RunMixin on _Melos {
  @override
  Future<void> run({
    GlobalOptions? global,
    String? scriptName,
    bool noSelect = false,
    List<String> extraArgs = const [],
  }) async {
    if (config.scripts.keys.isEmpty) throw NoScriptException._();

    scriptName ??= await _pickScript(config);
    final script = config.scripts[scriptName];

    if (script == null) {
      throw ScriptNotFoundException._(
        scriptName!,
        config.scripts.keys.toList(),
      );
    }

    final exitCode = await _runScript(
      script,
      config,
      global: global,
      noSelect: noSelect,
      extraArgs: extraArgs,
    );

    logger?.stdout('');
    logger?.stdout(AnsiStyles.yellow.bold('melos run ${script.name}'));
    logger?.stdout(
      '   └> ${AnsiStyles.cyan.bold(script.run.replaceAll('\n', ''))}',
    );

    if (exitCode != 0) {
      logger?.stdout('       └> ${AnsiStyles.red.bold('FAILED')}');
      throw ScriptException._(script.name);
    }
    logger?.stdout('       └> ${AnsiStyles.green.bold('SUCCESS')}');
  }

  Future<String?> _pickScript(MelosWorkspaceConfig config) async {
    // using toList as Maps may be unordered
    final scripts = config.scripts.values.toList();

    final scriptChoices = scripts.map((script) {
      final styledName = AnsiStyles.cyan(script.name);
      final styledDescription = script.description != null
          ? '\n    └> ${AnsiStyles.gray(script.description!.trim().split('\n').join('\n       '))}'
          : '';
      return '$styledName$styledDescription';
    }).toList();

    final selectedScript = prompts.choose(
      AnsiStyles.white('Select a script to run in this workspace'),
      scriptChoices,
      interactive: false,
    );

    final selectedScriptIndex = scriptChoices.indexOf(selectedScript!);

    if (selectedScriptIndex == -1) return null;

    return scripts[selectedScriptIndex].name;
  }

  Future<int> _runScript(
    Script script,
    MelosWorkspaceConfig config, {
    GlobalOptions? global,
    required bool noSelect,
    List<String> extraArgs = const [],
  }) async {
    final workspace = await MelosWorkspace.fromConfig(
      config,
      global: global,
      filter: script.filter?.copyWithUpdatedIgnore([
        ...script.filter!.ignore,
        ...config.ignore,
      ]),
      logger: logger,
    )
      ..validate();

    final environment = {
      'MELOS_ROOT_PATH': config.path,
      if (workspace.sdkPath != null) envKeyMelosSdkPath: workspace.sdkPath!,
      if (workspace.childProcessPath != null)
        'PATH': workspace.childProcessPath!,
      ...script.env,
    };

    if (script.filter != null) {
      final packages = workspace.filteredPackages.values.toList();

      var choices = packages.map((e) => AnsiStyles.cyan(e.name)).toList();

      if (choices.isEmpty) {
        throw NoPackageFoundScriptException._(
          script.filter,
          script.name,
        );
      }

      // Add a select all choice.
      if (choices.length > 1) {
        choices = [
          AnsiStyles.green('*'),
          ...choices,
        ];
      }

      String selectedPackage;
      if (choices.length == 1) {
        // Only 1 package - no need to prompt the user for a selection.
        selectedPackage = packages[0].name;
      } else if (noSelect) {
        // Skipping selection if flag present.
        selectedPackage = choices[0];
      } else {
        // Prompt user to select a package.
        selectedPackage = prompts.choose(
          [
            AnsiStyles.white('Select a package to run the '),
            AnsiStyles.cyan(script.name),
            AnsiStyles.white(' script'),
            AnsiStyles.gray(''),
          ].join(),
          choices,
          interactive: false,
          defaultsTo: choices[0],
        )!;
      }

      final selectedPackageIndex =
          choices.length > 1 ? choices.indexOf(selectedPackage) : 1;
      // Comma delimited string of packages selected (all or a single package).
      final packagesEnv = selectedPackageIndex == 0 && choices.length > 1
          ? packages.map((e) => e.name).toList().join(',')
          : packages[selectedPackageIndex - 1].name;
      // MELOS_PACKAGES environment is detected by melos itself when through
      // a defined script, this comma delimited list of package names is used
      // instead of any filters if detected.
      environment[envKeyMelosPackages] = packagesEnv;
    }

    final scriptSource = script.run;
    final scriptParts = scriptSource.split(' ');

    logger?.stdout(AnsiStyles.yellow.bold('melos run ${script.name}'));
    logger?.stdout(
      '   └> ${AnsiStyles.cyan.bold(scriptSource.replaceAll('\n', ''))}',
    );
    logger?.stdout('       └> ${AnsiStyles.yellow.bold('RUNNING')}\n');

    return startProcess(
      scriptParts..addAll(extraArgs),
      logger: logger,
      environment: environment,
      workingDirectory: config.path,
    );
  }
}

class NoPackageFoundScriptException implements MelosException {
  NoPackageFoundScriptException._(this.filter, this.scriptName);

  final PackageFilter? filter;
  final String? scriptName;

  @override
  String toString() {
    return 'NoPackageFoundScriptException: No package found that matches with '
        'the filters defined in the melos.yaml for script $scriptName.';
  }
}

class ScriptNotFoundException implements MelosException {
  ScriptNotFoundException._(this.scriptName, this.availableScriptNames);

  final String scriptName;
  final List<String> availableScriptNames;

  @override
  String toString() {
    final builder = StringBuffer(
      "ScriptNotFoundException: The script $scriptName could not be found in the 'melos.yaml' file.",
    );

    for (final scriptName in availableScriptNames) {
      builder.write('\n - $scriptName');
    }

    return builder.toString();
  }
}

class NoScriptException implements MelosException {
  NoScriptException._();

  @override
  String toString() {
    return "NoScriptException: This workspace has no scripts defined in it's 'melos.yaml' file.";
  }
}

class ScriptException implements MelosException {
  ScriptException._(this.scriptName);
  final String scriptName;

  @override
  String toString() {
    return 'ScriptException: The script $scriptName failed to execute';
  }
}
