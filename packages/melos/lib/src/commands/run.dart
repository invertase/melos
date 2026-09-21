part of 'runner.dart';

mixin _RunMixin on _Melos {
  @override
  Future<void> run({
    GlobalOptions? global,
    String? scriptName,
    bool? noSelect,
    bool listScripts = false,
    bool listScriptsAsJson = false,
    bool includePrivate = false,
    List<String> extraArgs = const [],
    String? group,
    PackageFilters? packageFilters,
    bool runUnchanged = false,
    bool? ignoreSources,
  }) async {
    final skipSelection = noSelect ?? config.commands.run.noSelect ?? false;
    final publicScripts = Map<String, Script>.from(config.scripts);
    if (!includePrivate) {
      publicScripts.removeWhere((_, script) => script.isPrivate);
    }

    if (group != null) {
      publicScripts.removeWhere(
        (_, script) => !(script.groups?.contains(group) ?? false),
      );
      if (publicScripts.isEmpty) {
        throw EmptyGroupException._(group);
      }
    }

    if (listScripts && scriptName == null) {
      _handleListScripts(
        publicScripts,
        listAsJson: listScriptsAsJson,
        group: group,
      );
      return;
    }

    if (config.scripts.keys.isEmpty) {
      throw NoScriptException._();
    }

    scriptName ??= await _pickScript(publicScripts);
    final script = publicScripts[scriptName];

    if (script == null) {
      throw ScriptNotFoundException._(
        scriptName,
        publicScripts.keys.toList(),
      );
    }

    _detectRecursiveScriptCalls(script);

    final scriptsToRun = config.scripts.inExecutionOrder(script);
    scriptsToRun.forEach(_validateScriptCommand);

    for (final scriptToRun in scriptsToRun) {
      final isRequestedScript = scriptToRun.name == script.name;
      try {
        await _runScriptWithoutDependencies(
          scriptToRun,
          global: global,
          skipSelection: skipSelection,
          extraArgs: isRequestedScript ? extraArgs : const [],
          packageFilters: packageFilters,
          runUnchanged: runUnchanged,
          ignoreSources: ignoreSources,
        );
      } on NoPackageFoundScriptException {
        if (isRequestedScript) {
          rethrow;
        }
        logger.warning(
          'Skipping the script ${scriptToRun.name}, that ${script.name} '
          'depends on, since no package matches its filters.',
        );
      }
    }
  }

  /// Throws if [script] does not specify what to run, or specifies it in a way
  /// that is not supported.
  void _validateScriptCommand(Script script) {
    final hasSteps = script.steps != null && script.steps!.isNotEmpty;
    if (hasSteps && script.exec != null) {
      throw ScriptExecOptionsException._(script.name);
    }

    if (!hasSteps && script.run == null && script.dependsOn.isEmpty) {
      throw MissingScriptCommandException._(script.name);
    }
  }

  /// Runs [script] on its own, assuming that the scripts that it depends on
  /// have already run.
  Future<void> _runScriptWithoutDependencies(
    Script script, {
    required bool skipSelection,
    GlobalOptions? global,
    List<String> extraArgs = const [],
    PackageFilters? packageFilters,
    bool runUnchanged = false,
    bool? ignoreSources,
  }) async {
    if (script.steps != null && script.steps!.isNotEmpty) {
      final exitCode = await _runMultipleScripts(
        script,
        global: global,
        noSelect: skipSelection,
        scripts: config.scripts,
        steps: script.steps!,
        packageFilters: packageFilters,
        runUnchanged: runUnchanged,
        ignoreSources: ignoreSources,
      );

      await _handleExitCode(exitCode, script.name);
      return;
    }

    if (script.run == null) {
      logger.command('melos run ${script.name}');
      logger.log(successLabel);
      return;
    }

    final scriptSourceCode = targetStyle(
      script
          .command(extraArgs: extraArgs, melosCommand: config.melosCommand)
          .join(' ')
          .withoutTrailing('\n'),
    );

    logger.command('melos run ${script.name}');
    logger.child(scriptSourceCode).child(runningLabel).newLine();
    await logger.flushGroupBufferIfNeed();

    final exitCode = await _runScript(
      script,
      global: global,
      noSelect: skipSelection,
      extraArgs: extraArgs,
      packageFilters: packageFilters,
      runUnchanged: runUnchanged,
      ignoreSources: ignoreSources,
    );

    await _handleExitCode(exitCode, script.name, logSuccess: false);
  }

  Future<void> _handleExitCode(
    int exitCode,
    String scriptName, {
    bool logSuccess = true,
  }) async {
    await logger.flushGroupBufferIfNeed();
    if (exitCode != 0) {
      logger.essential
        ..newLine()
        ..log(scriptName)
        ..child(failedLabel);
      throw ScriptException._(scriptName);
    }
    if (logSuccess) {
      logger.log(successLabel);
    }
  }

  void _handleListScripts(
    Map<String, Script> scripts, {
    bool listAsJson = false,
    String? group,
  }) {
    if (listAsJson) {
      logger.command(
        'melos run ${group != null ? '--group $group ' : ''}--list --json',
      );
      logger.newLine();
      logger.stdout(json.encode(scripts));
    } else {
      logger.command(
        'melos run ${group != null ? '--group $group ' : ''}--list',
      );
      logger.newLine();
      scripts.forEach((_, script) => logger.stdout(script.name));
    }
  }

  /// Detects recursive script calls within the provided [script].
  ///
  /// This method recursively traverses the steps of the script, and the
  /// scripts that it depends on, to check for any recursive calls. If a step
  /// or a dependency calls another script that eventually leads back to the
  /// original script, it indicates a recursive script call, which can result
  /// in an infinite loop during execution.
  void _detectRecursiveScriptCalls(Script script) {
    final visitedScripts = <String>{};
    final checkedScripts = <String>{};

    void traverseSteps(Script currentScript) {
      if (checkedScripts.contains(currentScript.name)) {
        return;
      }
      visitedScripts.add(currentScript.name);

      for (final step in [
        ...currentScript.dependsOn,
        ...?currentScript.steps,
      ]) {
        if (visitedScripts.contains(step)) {
          throw RecursiveScriptCallException._(step);
        }

        final nestedScript = config.scripts[step];
        if (nestedScript != null) {
          traverseSteps(nestedScript);
        }
      }

      visitedScripts.remove(currentScript.name);
      checkedScripts.add(currentScript.name);
    }

    traverseSteps(script);
  }

  /// Merges CLI package filters with script-defined package filters.
  ///
  /// When CLI filters are provided (e.g. --scope), the result is a new
  /// [PackageFilters] that combines script-defined filters with CLI overrides.
  /// CLI filters take precedence where provided.
  PackageFilters? _mergePackageFilters(
    PackageFilters? scriptFilters,
    PackageFilters? cliFilters,
  ) {
    if (cliFilters == null) return scriptFilters;
    if (scriptFilters == null) return cliFilters;

    List<T>? ifNotEmpty<T>(List<T> list) => list.isNotEmpty ? list : null;

    // CLI filters override script filters where provided.
    return scriptFilters.copyWith(
      scope: ifNotEmpty(cliFilters.scope),
      ignore: ifNotEmpty(cliFilters.ignore),
      categories: ifNotEmpty(cliFilters.categories),
      diff: cliFilters.diff,
      dirExists: ifNotEmpty(cliFilters.dirExists),
      fileExists: ifNotEmpty(cliFilters.fileExists),
      dependsOn: ifNotEmpty(cliFilters.dependsOn),
      noDependsOn: ifNotEmpty(cliFilters.noDependsOn),
      includePrivatePackages: cliFilters.includePrivatePackages,
      published: cliFilters.published,
      includeFlutterPackages: cliFilters.includeFlutterPackages,
      includeDependents: cliFilters.includeDependents ? true : null,
      includeDependencies: cliFilters.includeDependencies ? true : null,
      postFilters: _mergePackageFilters(
        scriptFilters.postFilters,
        cliFilters.postFilters,
      ),
    );
  }

  Future<String> _pickScript(Map<String, Script> scripts) async {
    // using toList as Maps may be unordered
    final scriptList = scripts.values.toList();

    final scriptChoices = scriptList.map((script) {
      final styledName = AnsiStyles.cyan(script.name);
      final styledDescription =
          script.description.let((description) {
            final formattedDescription = AnsiStyles.gray(
              description.trim().split('\n').join('\n       '),
            );
            return '\n    └> $formattedDescription';
          }) ??
          '';
      return '$styledName$styledDescription';
    }).toList();

    final selectedScript = promptChoice(
      AnsiStyles.white('Select a script to run in this workspace'),
      scriptChoices,
      interactive: false,
      requirePrompt: true,
    );

    final selectedScriptIndex = scriptChoices.indexOf(selectedScript);

    return scriptList[selectedScriptIndex].name;
  }

  @override
  Future<int> _runScript(
    Script script, {
    GlobalOptions? global,
    bool noSelect = false,
    List<String> extraArgs = const [],
    PackageFilters? packageFilters,
    bool runUnchanged = false,
    bool? ignoreSources,
  }) async {
    final mergedFilters = _mergePackageFilters(
      script.packageFilters,
      packageFilters,
    );
    final workspace =
        await createWorkspace(
            global: global,
            packageFilters: mergedFilters?.copyWithUpdatedIgnore([
              ...mergedFilters.ignore,
              ...config.ignore,
            ]),
          )
          ..validate();

    final environment = {
      EnvironmentVariableKey.melosRootPath: config.path,
      if (workspace.sdkPath != null)
        EnvironmentVariableKey.melosSdkPath: workspace.sdkPath!,
      if (workspace.childProcessPath != null)
        EnvironmentVariableKey.path: workspace.childProcessPath!,
      if (runUnchanged) EnvironmentVariableKey.melosRunUnchanged: 'true',
      if (ignoreSources != null)
        EnvironmentVariableKey.melosIgnoreSources: ignoreSources.toString(),
      ...script.env,
    };

    if (mergedFilters != null) {
      final packages = workspace.filteredPackages.values.toList();

      var choices = packages.map((e) => AnsiStyles.cyan(e.name)).toList();

      if (choices.isEmpty) {
        throw NoPackageFoundScriptException._(
          mergedFilters,
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
      } else if (noSelect || packageFilters != null) {
        // Skipping selection if flag present or CLI filters were provided.
        selectedPackage = choices[0];
      } else {
        // Prompt user to select a package.
        selectedPackage = promptChoice(
          [
            AnsiStyles.white('Select a package to run the '),
            AnsiStyles.cyan(script.name),
            AnsiStyles.white(' script'),
            AnsiStyles.gray(''),
          ].join(),
          choices,
          interactive: false,
          defaultsTo: choices[0],
        );
      }

      final selectedPackageIndex = choices.length > 1
          ? choices.indexOf(selectedPackage)
          : 1;
      // Comma delimited string of packages selected (all or a single package).
      final packagesEnv = selectedPackageIndex == 0 && choices.length > 1
          ? packages.map((e) => e.name).toList().join(',')
          : packages[selectedPackageIndex - 1].name;
      // MELOS_PACKAGES environment is detected by melos itself when through
      // a defined script, this comma delimited list of package names used to
      // scope the `packageFilters` if it is present.
      environment[EnvironmentVariableKey.melosPackages] = packagesEnv;
    }

    final inheritStdio = script.stdio == ProcessStdio.inherit;
    final group = logger.isQuiet && !inheritStdio ? script.name : null;

    final exitCode = await startCommand(
      script.command(extraArgs: extraArgs, melosCommand: config.melosCommand),
      logger: logger,
      environment: environment,
      workingDirectory: config.path,
      inheritStdio: inheritStdio,
      group: group,
    );

    if (group != null) {
      await _flushQuietGroup(group, exitCode: exitCode);
    }

    return exitCode;
  }

  /// Prints the output that was buffered for [group] in quiet mode if the
  /// command failed, and drops it otherwise.
  Future<void> _flushQuietGroup(String group, {required int exitCode}) async {
    if (exitCode == 0) {
      logger.discardGroup(group);
    }
    await logger.flushGroupBufferIfNeed();
  }

  Future<int> _runMultipleScripts(
    Script script, {
    required Scripts scripts,
    required List<String> steps,
    GlobalOptions? global,
    bool noSelect = false,
    PackageFilters? packageFilters,
    bool runUnchanged = false,
    bool? ignoreSources,
  }) async {
    final mergedFilters = _mergePackageFilters(
      script.packageFilters,
      packageFilters,
    );
    final workspace =
        await createWorkspace(
            global: global,
            packageFilters: mergedFilters,
          )
          ..validate();

    final environment = {
      EnvironmentVariableKey.melosRootPath: config.path,
      if (workspace.sdkPath != null)
        EnvironmentVariableKey.melosSdkPath: workspace.sdkPath!,
      if (workspace.childProcessPath != null)
        EnvironmentVariableKey.path: workspace.childProcessPath!,
      if (runUnchanged) EnvironmentVariableKey.melosRunUnchanged: 'true',
      if (ignoreSources != null)
        EnvironmentVariableKey.melosIgnoreSources: ignoreSources.toString(),
      ...script.env,
    };

    return _executeScriptSteps(steps, scripts, script, environment);
  }

  /// Checks if the given [step] is a recognized Melos command.
  bool _isStepACommand(String step) {
    // Split the step by spaces to separate the command from its flags/arguments.
    final command = step.split(' ')[0];

    const melosCommands = {
      'format',
      'bs',
      'bootstrap',
      'clean',
      'list',
      'publish',
    };

    return melosCommands.contains(command);
  }

  String _buildScriptCommand(String step, Scripts scripts) {
    final melos = config.melosCommand.join(' ');
    if (scripts.containsKey(step)) {
      return '$melos run $step --include-private';
    }

    if (_isStepACommand(step)) {
      return '$melos $step';
    }

    return step;
  }

  Future<int> _executeScriptSteps(
    List<String> steps,
    Scripts scripts,
    Script script,
    Map<String, String> environment,
  ) async {
    final shell = PersistentShell(
      logger: logger,
      workingDirectory: config.path,
      environment: environment,
    );

    await shell.startShell();
    logger.command('melos run ${script.name}');
    var exitCode = 0;

    for (final step in steps) {
      final scriptCommand = _buildScriptCommand(step, scripts);

      final group = logger.isQuiet ? step : null;

      exitCode = await shell.sendCommand(scriptCommand, group: group);
      if (group != null) {
        await _flushQuietGroup(group, exitCode: exitCode);
      }
      if (exitCode != 0) {
        break;
      }
    }

    await shell.stopShell();
    return exitCode;
  }
}

class NoPackageFoundScriptException implements MelosException {
  NoPackageFoundScriptException._(this.filters, this.scriptName);

  final PackageFilters? filters;
  final String? scriptName;

  @override
  String toString() {
    return 'NoPackageFoundScriptException: No package found that matches with '
        'the filters defined in the pubspec.yaml for script $scriptName.';
  }
}

class ScriptNotFoundException implements MelosException {
  ScriptNotFoundException._(this.scriptName, this.availableScriptNames);

  final String scriptName;
  final List<String> availableScriptNames;

  @override
  String toString() {
    final builder = StringBuffer(
      'ScriptNotFoundException: A script named $scriptName could not be found '
      "in the 'pubspec.yaml' file.",
    );

    if (scriptName.startsWith(extensionFieldPrefix)) {
      builder.write(
        ' Keys prefixed with "$extensionFieldPrefix" in "scripts" are '
        'extension fields for YAML anchors, not scripts. Rename the script to '
        'run it.',
      );
    }

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
    return 'NoScriptException: This workspace has no scripts defined in its '
        "'pubspec.yaml' file.";
  }
}

class ScriptException implements MelosException {
  ScriptException._(this.scriptName);
  final String scriptName;

  @override
  String toString() {
    return 'ScriptException: The script $scriptName failed to execute.';
  }
}

class ScriptExecOptionsException implements MelosException {
  ScriptExecOptionsException._(this.scriptName);
  final String scriptName;

  @override
  String toString() {
    return 'ScriptExecOptionsException: Execution options are not supported '
        'for the script "$scriptName". Ensure the script is designed to run '
        'with the provided options or consult the documentation for supported '
        'scripts.';
  }
}

class MissingScriptCommandException implements MelosException {
  MissingScriptCommandException._(this.scriptName);
  final String scriptName;

  @override
  String toString() {
    return 'MissingScriptCommandException: The script $scriptName failed '
        'to execute. You must specify a script to run. '
        'This can be done by filling "run" with a command, '
        'defining a sequence of commands in the "steps", '
        'providing a script execution definition in the "exec", '
        'or by listing the scripts to run in "dependsOn".';
  }
}

class RecursiveScriptCallException implements MelosException {
  RecursiveScriptCallException._(this.scriptName);

  final String scriptName;

  @override
  String toString() {
    return 'RecursiveScriptCallException: Detected a recursive call in script '
        'execution. The script "$scriptName" calls itself or forms a recursive '
        'loop.';
  }
}

class EmptyGroupException implements MelosException {
  EmptyGroupException._(this.group);

  final String group;

  @override
  String toString() {
    return 'EmptyGroupException: No scripts found in the group "$group".';
  }
}
