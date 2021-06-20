part of 'runner.dart';

mixin _ExecMixin on _Melos {
  Future<void> exec(
    List<String> execArgs, {
    PackageFilter? filter,
    int concurrency = 5,
    bool failFast = false,
  }) async {
    final workspace = await createWorkspace(filter: filter);
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
      'MELOS_PACKAGE_NAME': package.name,
      'MELOS_PACKAGE_VERSION': (package.version).toString(),
      'MELOS_PACKAGE_PATH': package.path,
      'MELOS_ROOT_PATH': workspace.path,
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

    return startProcess(
      execArgs,
      environment: environment,
      workingDirectory: package.path,
      prefix: prefixLogs ? packagePrefix : null,
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

    logger
        .stdout('${AnsiStyles.yellow(r'$')} ${AnsiStyles.bold("melos exec")}');
    logger.stdout('   └> ${AnsiStyles.cyan.bold(execArgsString)}');
    logger.stdout(
      '       └> ${AnsiStyles.yellow.bold('RUNNING')} (in ${packages.length} packages)',
    );

    if (prefixLogs) {
      logger.stdout('');
      logger.stdout('-' * terminalWidth);
    }

    await pool.forEach<Package, void>(packages, (package) async {
      if (failFast && failures.isNotEmpty) {
        return Future.value();
      }

      if (!prefixLogs) {
        logger.stdout('');
        logger.stdout('-' * terminalWidth);
        logger.stdout(AnsiStyles.bgBlack.bold.italic('${package.name}:'));
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
        logger.stdout(
          AnsiStyles.bgBlack.bold.italic('${package.name}: ') +
              AnsiStyles.bold.green.bgBlack('SUCCESS'),
        );
      }
    }).drain<void>();

    logger.stdout('-' * terminalWidth);
    logger.stdout('');

    logger
        .stdout('${AnsiStyles.yellow(r'$')} ${AnsiStyles.bold("melos exec")}');
    logger.stdout('   └> ${AnsiStyles.cyan.bold(execArgsString)}');

    if (failures.isNotEmpty) {
      logger.stdout(
        '       └> ${AnsiStyles.red.bold('FAILED')} (in ${failures.length} packages)',
      );
      for (final packageName in failures.keys) {
        logger.stdout(
          '           └> ${AnsiStyles.yellow(packageName)} (with exit code ${failures[packageName]})',
        );
      }
      exitCode = 1;
    } else {
      logger.stdout('       └> ${AnsiStyles.green.bold('SUCCESS')}');
    }
  }
}
