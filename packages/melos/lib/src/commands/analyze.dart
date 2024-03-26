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
    final analyzeArgsString = _getAnalyzeArgs(
      workspace: workspace,
      fatalInfos: fatalInfos,
      fatalWarnings: fatalWarnings,
      concurrency: concurrency,
    ).join(' ');
    final useGroupBuffer = concurrency != 1 && packages.length != 1;

    logger.command('melos analyze', withDollarSign: true);

    logger
        .child(targetStyle(analyzeArgsString))
        .child('$runningLabel (in ${packages.length} packages)')
        .newLine();

    await pool.forEach<Package, void>(packages, (package) async {
      final group = useGroupBuffer ? package.name : null;
      logger
        ..horizontalLine(group: group)
        ..log(AnsiStyles.bgBlack.bold.italic('${package.name}:'), group: group);

      final packageExitCode = await _analyzeForPackage(
        workspace,
        package,
        _getAnalyzeArgs(
          workspace: workspace,
          fatalInfos: fatalInfos,
          fatalWarnings: fatalWarnings,
        ),
        group: group,
      );

      if (packageExitCode > 0) {
        failures[package.name] = packageExitCode;
      } else {
        logger.log(
          AnsiStyles.bgBlack.bold.italic('${package.name}: ') +
              AnsiStyles.bgBlack(successLabel),
          group: group,
        );
      }
    }).drain<void>();

    logger.flushGroupBufferIfNeed();

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

  List<String> _getAnalyzeArgs({
    required MelosWorkspace workspace,
    required bool fatalInfos,
    bool? fatalWarnings,
    // Note: The `concurrency` argument is intentionally set to a default value
    // of 1 to prevent its direct use by the `startCommand` function. It is
    // designed to be utilized only for logging purposes to indicate the level
    // of concurrency being applied.
    int concurrency = 1,
  }) {
    final options = _getOptionsArgs(fatalInfos, fatalWarnings, concurrency);
    return <String>[
      ..._analyzeCommandExecArgs(
        useFlutter: workspace.isFlutterWorkspace,
        workspace: workspace,
      ),
      options,
    ];
  }

  String _getOptionsArgs(
    bool fatalInfos,
    bool? fatalWarnings,
    int concurrency,
  ) {
    final options = <String>[];

    if (fatalInfos) {
      options.add('--fatal-infos');
    }

    if (fatalWarnings != null) {
      options.add(fatalWarnings ? '--fatal-warnings' : '--no-fatal-warnings');
    }

    if (concurrency > 1) {
      options.add('--concurrency $concurrency');
    }

    return options.join(' ');
  }

  Future<int> _analyzeForPackage(
    MelosWorkspace workspace,
    Package package,
    List<String> analyzeArgs, {
    String? group,
  }) async {
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
      group: group,
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
