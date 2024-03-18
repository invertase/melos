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
    final packages = workspace.filteredPackages.values;

    await _execForAllPackages(
      workspace,
      packages,
      execArgs,
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
      final exampleParentPubspecPath =
          p.normalize('$exampleParentPackagePath/pubspec.yaml');

      if (fileExists(exampleParentPubspecPath)) {
        final exampleParentPackage = PubSpec.fromYamlString(
          await readTextFileAsync(exampleParentPubspecPath),
        );

        environment[EnvironmentVariableKey.melosParentPackageName] =
            exampleParentPackage.name!;
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
    required bool orderDependents,
    Map<String, String> additionalEnvironment = const {},
  }) async {
    final failures = <String, int?>{};
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

    final sortedPackages = packages.toList(growable: false);

    if (orderDependents) {
      // TODO: This is not really the right way to do this. Cyclic dependencies
      // are handled in a way that is specific for publishing.
      sortPackagesForPublishing(sortedPackages);
    }

    final packageResults = Map.fromEntries(
      packages.map((package) => MapEntry(package.name, Completer<int?>())),
    );

    late final CancelableOperation<void> operation;

    operation = CancelableOperation.fromFuture(
      pool.forEach<Package, void>(sortedPackages, (package) async {
        assert(!(failFast && failures.isNotEmpty));

        if (orderDependents) {
          final dependenciesResults = await Future.wait(
            package.allDependenciesInWorkspace.values
                .map((package) => packageResults[package.name]?.future)
                .whereNotNull(),
          );

          final dependencyFailed = dependenciesResults.any(
            (exitCode) => exitCode == null || exitCode > 0,
          );
          if (dependencyFailed) {
            packageResults[package.name]?.complete();
            failures[package.name] = null;

            return;
          }
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
          '${failures[packageName] == null ? '(dependency failed)' : '('
              'with exit code ${failures[packageName]})'}',
        );
      }

      final canceled = <String>[];
      for (final package in packages) {
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
        final canceledLogger = resultLogger
            .child('$canceledLabel (in ${canceled.length} packages)');
        for (final packageName in canceled) {
          canceledLogger.child(
            '${errorPackageNameStyle(packageName)} (due to failFast)',
          );
        }
      }

      exitCode = 1;
    } else {
      resultLogger.child(successLabel);
    }
  }
}
