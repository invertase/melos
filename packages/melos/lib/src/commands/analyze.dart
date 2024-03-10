part of 'runner.dart';

mixin _AnalyzeMixin on _Melos {
  Future<void> analyze({
    GlobalOptions? global,
    PackageFilters? packageFilters,
    bool fatalInfos = false,
    bool? fatalWarnings,
    int concurrency = 1,
  }) async {
    final workspace =
        await createWorkspace(global: global, packageFilters: packageFilters);
    final packages = workspace.filteredPackages.values;

    await _analyzeForAllPackages(
      workspace,
      packages,
      fatalInfos: fatalInfos,
      fatalWarnings: fatalWarnings,
      concurrency: concurrency,
    );
  }

  Future<void> _analyzeForAllPackages(
    MelosWorkspace workspace,
    Iterable<Package> packages, {
    required bool fatalInfos,
    bool? fatalWarnings,
    required int concurrency,
  }) async {
    final failures = <String, int?>{};
    final pool = Pool(concurrency);
    final analyzeArgs = _getAnalyzeArgs(
      workspace,
      fatalInfos,
      fatalWarnings,
    );
    final analyzeArgsString = analyzeArgs.join(' ');
    final prefixLogs = concurrency != 1 && packages.length != 1;

    logger.command('melos analyze', withDollarSign: true);

    logger
        .child(targetStyle(analyzeArgsString))
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

      final packageExitCode = await _analyzeForPackage(
        workspace,
        package,
        analyzeArgs,
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
      ..command('melos analyze', withDollarSign: true);

    final resultLogger = logger.child(targetStyle(analyzeArgsString));

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

  List<String> _getAnalyzeArgs(
    MelosWorkspace workspace,
    bool fatalInfos,
    bool? fatalWarnings,
  ) {
    final options = _getOptionsArgs(fatalInfos, fatalWarnings);
    return <String>[
      ..._analyzeCommandExecArgs(
        useFlutter: workspace.isFlutterWorkspace,
        workspace: workspace,
      ),
      options,
    ];
  }

  String _getOptionsArgs(bool fatalInfos, bool? fatalWarnings) {
    var options = '';

    if (fatalInfos) {
      options = '--fatal-infos';
    }

    if (fatalWarnings != null) {
      options = fatalWarnings ? '--fatal-warnings' : '--no-fatal-warnings';
    }

    return options;
  }

  Future<int> _analyzeForPackage(
    MelosWorkspace workspace,
    Package package,
    List<String> analyzeArgs,
  ) async {
    final environment = {
      EnvironmentVariableKey.melosRootPath: config.path,
      if (workspace.sdkPath != null)
        EnvironmentVariableKey.melosSdkPath: workspace.sdkPath!,
      if (workspace.childProcessPath != null)
        EnvironmentVariableKey.path: workspace.childProcessPath!,
    };

    return startCommand(
      analyzeArgs,
      logger: logger,
      environment: environment,
      workingDirectory: package.path,
    );
  }

  List<String> _analyzeCommandExecArgs({
    required bool useFlutter,
    required MelosWorkspace workspace,
  }) {
    return [
      if (useFlutter)
        workspace.sdkTool('flutter')
      else
        workspace.sdkTool('dart'),
      'analyze',
    ];
  }
}
