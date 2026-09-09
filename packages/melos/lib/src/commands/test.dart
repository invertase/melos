part of 'runner.dart';

mixin _TestMixin on _Melos {
  Future<void> test({
    GlobalOptions? global,
    PackageFilters? packageFilters,
    int? concurrency,
    bool? noPub,
  }) async {
    final workspace = await createWorkspace(
      global: global,
      packageFilters: packageFilters,
    );
    final packages = workspace.filteredPackages.values.where(
      (pkg) => Directory(p.join(pkg.path, 'test')).existsSync(),
    );
    final testConfig = workspace.config.commands.test;

    await _testForAllPackages(
      workspace,
      packages,
      concurrency: concurrency ?? testConfig.concurrency ?? 1,
      noPub: noPub ?? testConfig.noPub ?? false,
    );
  }

  Future<void> _testForAllPackages(
    MelosWorkspace workspace,
    Iterable<Package> packages, {
    required int concurrency,
    required bool noPub,
  }) async {
    if (packages.isEmpty) {
      logger.command('melos test', withDollarSign: true);
      logger.child('No packages with a test/ directory found.');
      return;
    }

    final failures = <String, int?>{};
    final pool = Pool(concurrency);
    final testArgsString = _getTestArgs(
      workspace: workspace,
      concurrency: concurrency,
      noPub: noPub,
    ).join(' ');
    final useGroupBuffer = concurrency != 1 && packages.length != 1;
    final dartPackageCount = packages.where((e) => !e.isFlutterPackage).length;
    final flutterPackageCount = packages
        .where((e) => e.isFlutterPackage)
        .length;

    logger.command('melos test', withDollarSign: true);

    if (dartPackageCount > 0) {
      logger
          .child(targetStyle(testArgsString))
          .child('$runningLabel (in $dartPackageCount packages)')
          .newLine();
    }

    if (flutterPackageCount > 0) {
      final flutterTestArgsString = _getTestArgs(
        workspace: workspace,
        concurrency: concurrency,
        noPub: noPub,
        isFlutter: true,
      ).join(' ');
      logger
          .child(targetStyle(flutterTestArgsString))
          .child('$runningLabel (in $flutterPackageCount packages)')
          .newLine();
    }

    await pool.forEach<Package, void>(packages, (package) async {
      final group = useGroupBuffer ? package.name : null;
      logger
        ..horizontalLine(group: group)
        ..log(AnsiStyles.bgBlack.bold.italic('${package.name}:'), group: group);

      final packageExitCode = await _testForPackage(
        workspace,
        package,
        _getTestArgs(
          package: package,
          workspace: workspace,
          concurrency: concurrency,
          noPub: noPub,
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
      ..command('melos test', withDollarSign: true);

    final resultLogger = logger.child(targetStyle(testArgsString));

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

  List<String> _getTestArgs({
    required MelosWorkspace workspace,
    Package? package,
    int concurrency = 1,
    bool noPub = false,
    bool isFlutter = false,
  }) {
    final useFlutter = package?.isFlutterPackage ?? isFlutter;
    final options = _getOptionsArgs(
      concurrency: concurrency,
      noPub: noPub,
      isFlutter: useFlutter,
    );
    return <String>[
      if (useFlutter)
        workspace.sdkTool('flutter')
      else
        workspace.sdkTool('dart'),
      'test',
      options,
    ];
  }

  String _getOptionsArgs({
    required int concurrency,
    required bool noPub,
    required bool isFlutter,
  }) {
    final options = <String>[];
    if (concurrency > 1) {
      options.add('--concurrency=$concurrency');
    }
    // `dart test` has no `--no-pub` flag, see
    // https://github.com/dart-lang/sdk/issues/45307.
    if (noPub && isFlutter) {
      options.add('--no-pub');
    }
    return options.join(' ');
  }

  Future<int> _testForPackage(
    MelosWorkspace workspace,
    Package package,
    List<String> testArgs, {
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
      testArgs,
      logger: logger,
      environment: environment,
      workingDirectory: package.path,
      group: group,
    );
  }
}
