part of 'runner.dart';

mixin _ExecMixin on _Melos {
  Future<void> exec(
    List<String> execArgs, {
    GlobalOptions? global,
    PackageFilters? packageFilters,
    int? concurrency,
    bool failFast = false,
    bool orderDependents = false,
    Map<String, String> extraEnvironment = const {},
  }) async {
    concurrency ??= Platform.numberOfProcessors;
    final workspace = await createWorkspace(
      global: global,
      packageFilters: packageFilters,
    );
    final allPackages = workspace.allPackages.values.toList(growable: false);
    final executablePackages = workspace.filteredPackages.values.toList(
      growable: false,
    );

    if (orderDependents) {
      final cycles = findCyclicDependenciesInWorkspace(allPackages);
      if (cycles.isNotEmpty) {
        printCyclesInDependencies(cycles, logger);
        exitCode = 1;
        return;
      }
    }

    await _execForAllPackages(
      workspace,
      execArgs,
      executablePackages: executablePackages,
      failFast: failFast,
      concurrency: concurrency,
      orderDependents: orderDependents,
      additionalEnvironment: extraEnvironment,
    );
  }

  /// Execute a shell command inside this package.
  Future<int> _execForPackage(
    MelosWorkspace workspace,
    Package package,
    List<String> execArgs, {
    bool prefixLogs = true,
    Map<String, String> extraEnvironment = const {},
  }) async {
    final packagePrefix = '[${AnsiStyles.blue.bold(package.name)}]: ';

    final environment = {
      ...currentPlatform.environment,
      ...extraEnvironment,
      EnvironmentVariableKey.melosPackageName: package.name,
      EnvironmentVariableKey.melosPackageVersion: package.version.toString(),
      EnvironmentVariableKey.melosPackagePath: package.path,
      EnvironmentVariableKey.melosRootPath: workspace.path,
      if (workspace.sdkPath != null)
        EnvironmentVariableKey.melosSdkPath: workspace.sdkPath!,
      if (workspace.childProcessPath != null)
        EnvironmentVariableKey.path: workspace.childProcessPath!,
    };

    if (package.isExample) {
      final exampleParentPackagePath = p.normalize('${package.path}/..');
      final exampleParentPubspecPath = p.normalize(
        '$exampleParentPackagePath/pubspec.yaml',
      );

      if (fileExists(exampleParentPubspecPath)) {
        final exampleParentPackage = Pubspec.parse(
          await readTextFileAsync(exampleParentPubspecPath),
        );

        environment[EnvironmentVariableKey.melosParentPackageName] =
            exampleParentPackage.name;
        environment[EnvironmentVariableKey.melosParentPackageVersion] =
            (exampleParentPackage.version ?? Version.none).toString();
        environment[EnvironmentVariableKey.melosParentPackagePath] =
            exampleParentPackagePath;
      }
    }
    if (environment.containsKey(EnvironmentVariableKey.melosTest)) {
      EnvironmentVariableKey.allMelosKeys().forEach(environment.remove);
    }

    return startCommand(
      execArgs,
      logger: logger,
      environment: environment,
      workingDirectory: package.path,
      logPrefix: prefixLogs ? packagePrefix : null,
      // The parent env is injected manually above
      includeParentEnvironment: false,
    );
  }

  Future<void> _execForAllPackages(
    MelosWorkspace workspace,
    List<String> execArgs, {
    required Iterable<Package> executablePackages,
    required int concurrency,
    required bool failFast,
    required bool orderDependents,
    Map<String, String> additionalEnvironment = const {},
  }) async {
    final allPackagesList = workspace.allPackages.values.toList(
      growable: false,
    );
    final executablePackagesList = executablePackages.toList(growable: false);
    final List<List<Package>> sortedPackageLayers;

    if (orderDependents) {
      final allPackagesLayers = sortPackagesForExecution(allPackagesList);
      sortedPackageLayers = whereOnlyExecutablePackages(
        allPackagesLayers,
        executablePackagesList,
      );
    } else {
      sortedPackageLayers = [executablePackagesList];
    }

    final failures = <String, int?>{};
    final pool = Pool(concurrency);

    final execArgsString = execArgs.join(' ');
    final prefixLogs = concurrency != 1 && executablePackages.length != 1;

    logger.command('melos exec', withDollarSign: true);
    logger
        .child(targetStyle(execArgsString))
        .child('$runningLabel (in ${executablePackages.length} packages)')
        .newLine();
    if (prefixLogs) {
      logger.horizontalLine();
    }

    final packageResults = Map.fromEntries(
      executablePackages.map(
        (package) => MapEntry(package.name, Completer<int?>()),
      ),
    );

    for (final packageLayer in sortedPackageLayers) {
      late final CancelableOperation<void> operation;

      operation = CancelableOperation.fromFuture(
        pool.forEach<Package, void>(packageLayer, (package) async {
          if (failFast && failures.isNotEmpty) {
            packageResults[package.name]?.complete();
            failures[package.name] = null;
            return;
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
            extraEnvironment: additionalEnvironment,
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

          if (packageExitCode > 0 && failFast) {
            await operation.cancel();
          }
        }).drain<void>(),
      );

      await operation.valueOrCancellation();
      if (failFast) {
        runningPids.forEach(Process.killPid);
      }
    }

    logger
      ..horizontalLine()
      ..newLine()
      ..command('melos exec', withDollarSign: true);

    final resultLogger = logger.child(targetStyle(execArgsString));

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

      final canceled = <String>[];
      for (final package in executablePackages) {
        if (failures.containsKey(package.name)) {
          continue;
        }

        if (packageResults.containsKey(package.name)) {
          final packageResult = packageResults[package.name]!;

          if (packageResult.isCompleted) {
            final exitCode = await packageResult.future;

            if (exitCode == 0) {
              continue;
            }
          }
        }

        canceled.add(package.name);
      }

      if (canceled.isNotEmpty) {
        final canceledLogger = resultLogger.child(
          '$canceledLabel (in ${canceled.length} packages)',
        );
        for (final packageName in canceled) {
          canceledLogger.child(
            '${errorPackageNameStyle(packageName)} (due to failFast)',
          );
        }
      }

      exitCode = failFast ? failures[failures.keys.first]! : 1;
    } else {
      resultLogger.child(successLabel);
    }
  }
}
