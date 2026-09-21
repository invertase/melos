part of 'runner.dart';

mixin _FormatMixin on _Melos {
  Future<void> format({
    GlobalOptions? global,
    PackageFilters? packageFilters,
    int? concurrency,
    bool? setExitIfChanged,
    String? output,
    int? lineLength,
  }) async {
    final workspace = await createWorkspace(
      global: global,
      packageFilters: packageFilters,
    );
    final packages = workspace.filteredPackages.values;

    await _formatForAllPackages(
      workspace,
      packages,
      concurrency: concurrency,
      setExitIfChanged: setExitIfChanged,
      output: output,
      lineLength: lineLength,
    );
  }

  Future<void> _formatForAllPackages(
    MelosWorkspace workspace,
    Iterable<Package> packages, {
    int? concurrency,
    bool? setExitIfChanged,
    String? output,
    int? lineLength,
  }) async {
    final formatConfig = workspace.config.commands.format;

    final effectiveConcurrency = concurrency ?? formatConfig.concurrency ?? 1;
    final effectiveSetExitIfChanged =
        setExitIfChanged ?? formatConfig.setExitIfChanged;
    final effectiveLineLength = lineLength ?? formatConfig.lineLength;
    final effectiveOutput = output ?? formatConfig.output;

    final failures = <String, int?>{};
    final pool = Pool(effectiveConcurrency);
    final formatArgs = [
      'dart',
      'format',
      if (effectiveSetExitIfChanged ?? false) '--set-exit-if-changed',
      if (effectiveOutput != null) '--output $effectiveOutput',
      if (effectiveLineLength != null) '--line-length $effectiveLineLength',
      '.',
    ];
    final formatArgsString = formatArgs.join(' ');
    final prefixLogs =
        !logger.isQuiet && effectiveConcurrency != 1 && packages.length != 1;

    logger.command('melos format', withDollarSign: true);

    logger
        .child(targetStyle(formatArgsString))
        .child('$runningLabel (in ${packages.length} packages)')
        .newLine();
    if (prefixLogs) {
      logger.horizontalLine();
    }

    final packageResults = Map.fromEntries(
      packages.map((package) => MapEntry(package.name, Completer<int?>())),
    );

    await pool.forEach<Package, void>(packages, (package) async {
      final group = logger.isQuiet ? package.name : null;

      if (!prefixLogs) {
        logger
          ..horizontalLine(group: group)
          ..log(
            AnsiStyles.bgBlack.bold.italic('${package.name}:'),
            group: group,
          );
      }

      final packageExitCode = await _formatForPackage(
        workspace,
        package,
        formatArgs,
        prefixLogs: prefixLogs,
        group: group,
      );

      packageResults[package.name]?.complete(packageExitCode);

      if (packageExitCode > 0) {
        failures[package.name] = packageExitCode;
      } else if (logger.isQuiet) {
        logger.discardGroup(package.name);
      } else if (!prefixLogs) {
        logger.log(
          AnsiStyles.bgBlack.bold.italic('${package.name}: ') +
              AnsiStyles.bgBlack(successLabel),
        );
      }
    }).drain<void>();

    await logger.flushGroupBufferIfNeed();

    final summaryLogger = failures.isEmpty ? logger : logger.essential;

    summaryLogger
      ..horizontalLine()
      ..newLine()
      ..command('melos format', withDollarSign: true);

    final resultLogger = summaryLogger.child(targetStyle(formatArgsString));

    if (failures.isNotEmpty) {
      final failuresLogger = resultLogger.child(
        '$failedLabel (in ${failures.length} packages)',
      );
      for (final packageName in failures.keys) {
        failuresLogger.child(
          '${errorPackageNameStyle(packageName)} '
          '${failures[packageName] == null ? '(dependency failed)' : '('
                    'with exit code ${failures[packageName]})'}',
        );
      }
      exitCode = 1;
    } else {
      resultLogger.child(successLabel);
    }
  }

  Future<int> _formatForPackage(
    MelosWorkspace workspace,
    Package package,
    List<String> formatArgs, {
    bool prefixLogs = true,
    String? group,
  }) async {
    final packagePrefix = '[${AnsiStyles.blue.bold(package.name)}]: ';

    final environment = {
      EnvironmentVariableKey.melosRootPath: config.path,
      if (workspace.sdkPath != null)
        EnvironmentVariableKey.melosSdkPath: workspace.sdkPath!,
      if (workspace.childProcessPath != null)
        EnvironmentVariableKey.path: workspace.childProcessPath!,
    };

    return startCommand(
      formatArgs,
      logger: logger,
      environment: environment,
      workingDirectory: package.path,
      logPrefix: prefixLogs ? packagePrefix : null,
      group: group,
    );
  }
}
