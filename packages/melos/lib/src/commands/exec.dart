part of 'runner.dart';

mixin _ExecMixin on _Melos {
  Future<void> exec(
    List<String> execArgs, {
    GlobalOptions? global,
    PackageFilter? filter,
    int concurrency = 5,
    bool failFast = false,
  }) async {
    final workspace = await createWorkspace(global: global, filter: filter);
    final packages = workspace.filteredPackages.values;

    await _execForAllPackages(
      workspace,
      packages,
      execArgs,
      failFast: failFast,
      concurrency: concurrency,
    );
  }

  /// Execute a shell command inside this package.
  Future<int> _execForPackage(
    MelosWorkspace workspace,
    Package package,
    List<String> execArgs, {
    bool prefixLogs = true,
  }) async {
    final packagePrefix = '[${AnsiStyles.blue.bold(package.name)}]: ';

    final environment = {
      ...currentPlatform.environment,
      'MELOS_PACKAGE_NAME': package.name,
      'MELOS_PACKAGE_VERSION': (package.version).toString(),
      'MELOS_PACKAGE_PATH': package.path,
      'MELOS_ROOT_PATH': workspace.path,
      if (workspace.sdkPath != null) envKeyMelosSdkPath: workspace.sdkPath!,
      if (workspace.childProcessPath != null)
        'PATH': workspace.childProcessPath!,
    };

    // TODO what if it's not called 'example'?
    if (package.path.endsWith('example')) {
      final exampleParentPackagePath = Directory(package.path).parent.path;
      final exampleParentPubspecFile = File(
        '$exampleParentPackagePath${currentPlatform.pathSeparator}pubspec.yaml',
      );

      if (exampleParentPubspecFile.existsSync()) {
        final exampleParentPackage =
            await PubSpec.load(exampleParentPubspecFile.parent);

        environment['MELOS_PARENT_PACKAGE_NAME'] = exampleParentPackage.name!;
        environment['MELOS_PARENT_PACKAGE_VERSION'] =
            (exampleParentPackage.version ?? Version.none).toString();
        environment['MELOS_PARENT_PACKAGE_PATH'] =
            exampleParentPubspecFile.parent.path;
      }
    }
    if (environment.containsKey('MELOS_TEST')) {
      // TODO(rrousselGit) refactor this to not have to manually maitain the list
      // of env variables to remove
      environment.remove('MELOS_TEST');
      environment.remove('MELOS_ROOT_PATH');
      environment.remove('MELOS_SCRIPT');
      environment.remove('MELOS_PACKAGE_NAME');
      environment.remove('MELOS_PACKAGE_VERSION');
      environment.remove('MELOS_PACKAGE_PATH');
      environment.remove('MELOS_PARENT_PACKAGE_NAME');
      environment.remove('MELOS_PARENT_PACKAGE_VERSION');
      environment.remove('MELOS_PARENT_PACKAGE_PATH');
      environment.remove(envKeyMelosPackages);
      environment.remove(envKeyMelosSdkPath);
      environment.remove(envKeyMelosTerminalWidth);
    }

    return startProcess(
      execArgs,
      logger: logger,
      environment: environment,
      workingDirectory: package.path,
      prefix: prefixLogs ? packagePrefix : null,
      // The parent env is injected manually above
      includeParentEnvironment: false,
    );
  }

  Future<void> _execForAllPackages(
    MelosWorkspace workspace,
    Iterable<Package> packages,
    List<String> execArgs, {
    required int concurrency,
    required bool failFast,
  }) async {
    final failures = <String, int>{};
    final pool = Pool(concurrency);
    final execArgsString = execArgs.join(' ');
    final prefixLogs = concurrency != 1 && packages.length != 1;

    logger.command('melos exec', withDollarSign: true);
    logger
        .child(targetStyle(execArgsString))
        .child('$runningLabel (in ${packages.length} packages)')
        .newLine();
    if (prefixLogs) {
      logger.horizontalLine();
    }

    await pool.forEach<Package, void>(packages, (package) async {
      if (failFast && failures.isNotEmpty) {
        return Future.value();
      }

      if (!prefixLogs) {
        logger
          ..horizontalLine()
          ..log(AnsiStyles.bgBlack.bold.italic('${package.name}:'));
      }

      final packageExitCode = await _execForPackage(
        workspace,
        package,
        execArgs,
        prefixLogs: prefixLogs,
      );

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
      ..command('melos exec', withDollarSign: true);

    final resultLogger = logger.child(targetStyle(execArgsString));

    if (failures.isNotEmpty) {
      final failuresLogger =
          resultLogger.child('$failedLabel (in ${failures.length} packages)');
      for (final packageName in failures.keys) {
        failuresLogger.child(
          '${errorPackageNameStyle(packageName)} '
          '(with exit code ${failures[packageName]})',
        );
      }
      exitCode = 1;
    } else {
      resultLogger.child(successLabel);
    }
  }
}
