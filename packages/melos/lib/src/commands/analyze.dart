part of 'runner.dart';

mixin _AnalyzeMixin on _Melos {
  Future<void> analyze({
    GlobalOptions? global,
    PackageFilters? packageFilters,
    bool fatalInfos = true,
    bool? fatalWarnings,
    int concurrency = 1,
  }) async {
    final workspace = await createWorkspace(
      global: global,
      packageFilters: packageFilters,
    );
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
    final dartAnalyzeArgsString = _getAnalyzeArgs(
      workspace: workspace,
      fatalInfos: fatalInfos,
      fatalWarnings: fatalWarnings,
      concurrency: concurrency,
    ).join(' ');
    final useGroupBuffer = concurrency != 1 && packages.length != 1;
    final dartPackageCount = packages.where((e) => !e.isFlutterPackage).length;
    final flutterPackageCount = packages
        .where((e) => e.isFlutterPackage)
        .length;

    logger.command('melos analyze', withDollarSign: true);

    if (dartPackageCount > 0) {
      logger
          .child(targetStyle(dartAnalyzeArgsString))
          .child('$runningLabel (in $dartPackageCount packages)')
          .newLine();
    }

    if (flutterPackageCount > 0) {
      final flutterAnalyzeArgsString = _getAnalyzeArgs(
        workspace: workspace,
        fatalInfos: fatalInfos,
        fatalWarnings: fatalWarnings,
        concurrency: concurrency,
        isFlutter: true,
      ).join(' ');
      logger
          .child(targetStyle(flutterAnalyzeArgsString))
          .child('$runningLabel (in $flutterPackageCount packages)')
          .newLine();
    }

    await pool.forEach<Package, void>(packages, (package) async {
      final group = useGroupBuffer ? package.name : null;
      logger
        ..horizontalLine(group: group)
        ..log(AnsiStyles.bgBlack.bold.italic('${package.name}:'), group: group);

      final packageExitCode = await _analyzeForPackage(
        workspace,
        package,
        _getAnalyzeArgs(
          package: package,
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

    await logger.flushGroupBufferIfNeed();

    logger
      ..horizontalLine()
      ..newLine()
      ..command('melos analyze', withDollarSign: true);

    final resultLogger = logger.child(targetStyle(dartAnalyzeArgsString));

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

  List<String> _getAnalyzeArgs({
    required MelosWorkspace workspace,
    required bool fatalInfos,
    Package? package,
    bool? fatalWarnings,
    bool isFlutter = false,
    int concurrency = 1,
  }) {
    final useFlutter = package?.isFlutterPackage ?? isFlutter;
    final options = _getAnalyzeOptionsArgs(
      fatalInfos: fatalInfos,
      fatalWarnings: fatalWarnings,
      concurrency: concurrency,
      isFlutter: useFlutter,
    );
    return <String>[
      if (useFlutter)
        workspace.sdkTool('flutter')
      else
        workspace.sdkTool('dart'),
      'analyze',
      options,
    ];
  }

  String _getAnalyzeOptionsArgs({
    required bool fatalInfos,
    required bool? fatalWarnings,
    required int concurrency,
    required bool isFlutter,
  }) {
    final options = <String>[];

    if (fatalInfos) {
      options.add('--fatal-infos');
    } else if (isFlutter) {
      options.add('--no-fatal-infos');
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
}
