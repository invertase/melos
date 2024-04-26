part of 'runner.dart';

mixin _FormatMixin on _Melos {
  Future<void> format({
    GlobalOptions? global,
    PackageFilters? packageFilters,
    int concurrency = 1,
    bool? setExitIfChanged,
    String? output,
    int? lineLength,
  }) async {
    final workspace =
        await createWorkspace(global: global, packageFilters: packageFilters);
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
    required int concurrency,
    bool? setExitIfChanged,
    String? output,
    int? lineLength,
  }) async {
    final formatConfig = workspace.config.commands.format;

    final effectiveSetExitIfChanged =
        setExitIfChanged ?? formatConfig.setExitIfChanged;
    final effectiveLineLength = lineLength ?? formatConfig.lineLength;

    final failures = <String, int?>{};
    final pool = Pool(concurrency);
    final formatArgs = [
      'dart',
      'format',
      if (effectiveSetExitIfChanged ?? false) '--set-exit-if-changed',
      if (output != null) '--output $output',
      if (effectiveLineLength != null) '--line-length $effectiveLineLength',
      '.',
    ];
    final formatArgsString = formatArgs.join(' ');
    final prefixLogs = concurrency != 1 && packages.length != 1;

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
      if (!prefixLogs) {
        logger
          ..horizontalLine()
          ..log(AnsiStyles.bgBlack.bold.italic('${package.name}:'));
      }

      final packageExitCode = await _formatForPackage(
        workspace,
        package,
        formatArgs,
        prefixLogs: prefixLogs,
      );

      packageResults[package.name]?.complete(packageExitCode);

      if (packageExitCode > 0) {
        failures[package.name] = packageExitCode;
      } else if (!prefixLogs) {
        logger.log(
          AnsiStyles.bgBlack.bold.italic('${package.name}: ') +
              AnsiStyles.bgBlack(successLabel),
        );
      }
    }).drain<void>();

    logger
      ..horizontalLine()
      ..newLine()
      ..command('melos format', withDollarSign: true);

    final resultLogger = logger.child(targetStyle(formatArgsString));

    if (failures.isNotEmpty) {
      final failuresLogger =
          resultLogger.child('$failedLabel (in ${failures.length} packages)');
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
      prefix: prefixLogs ? packagePrefix : null,
    );
  }
}
