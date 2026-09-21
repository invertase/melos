part of 'runner.dart';

mixin _ExecMixin on _Melos {
  Future<void> exec(
    List<String> execArgs, {
    GlobalOptions? global,
    PackageFilters? packageFilters,
    int? concurrency,
    bool? failFast,
    bool? orderDependents,
    bool? groupLogs,
    List<String> sources = const [],
    bool force = false,
    bool? ignoreSources,
    Map<String, String> extraEnvironment = const {},
  }) async {
    final workspace = await createWorkspace(
      global: global,
      packageFilters: packageFilters,
    );
    final execConfig = workspace.config.commands.exec;
    final effectiveConcurrency =
        concurrency ?? execConfig.concurrency ?? Platform.numberOfProcessors;
    final effectiveFailFast = failFast ?? execConfig.failFast ?? false;
    final effectiveOrderDependents =
        orderDependents ?? execConfig.orderDependents ?? false;
    final effectiveGroupLogs = groupLogs ?? execConfig.groupLogs ?? false;
    final effectiveIgnoreSources =
        ignoreSources ?? execConfig.ignoreSources ?? false;
    final allPackages = workspace.allPackages.values.toList(growable: false);
    final executablePackages = workspace.filteredPackages.values.toList(
      growable: false,
    );

    if (effectiveOrderDependents) {
      final cycles = findCyclicDependenciesInWorkspace(allPackages);
      if (cycles.isNotEmpty) {
        printCyclesInDependencies(cycles, logger);
        exitCode = 1;
        return;
      }
    }

    final fingerprints = sources.isEmpty
        ? null
        : ExecFingerprints(command: execArgs, sources: sources);
    if (effectiveIgnoreSources) {
      // The command runs without checksums, so the stored ones no longer say
      // anything about the result of the last run.
      fingerprints?.removeStored(executablePackages);
    }

    await _execForAllPackages(
      workspace,
      execArgs,
      executablePackages: executablePackages,
      failFast: effectiveFailFast,
      concurrency: effectiveConcurrency,
      orderDependents: effectiveOrderDependents,
      groupLogs: effectiveGroupLogs,
      fingerprints: effectiveIgnoreSources ? null : fingerprints,
      force: force,
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
    ProcessOutputCancelToken? cancelToken,
    String? group,
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
      cancelToken: cancelToken,
      group: group,
    );
  }

  Future<void> _execForAllPackages(
    MelosWorkspace workspace,
    List<String> execArgs, {
    required Iterable<Package> executablePackages,
    required int concurrency,
    required bool failFast,
    required bool orderDependents,
    bool groupLogs = false,
    ExecFingerprints? fingerprints,
    bool force = false,
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
    final skipped = <String>[];
    final pool = Pool(concurrency);

    final execArgsString = execArgs.join(' ');
    final isConcurrent = concurrency != 1 && executablePackagesList.length != 1;
    final useGroupBuffer = logger.isQuiet || (groupLogs && isConcurrent);
    final prefixLogs = isConcurrent && !useGroupBuffer;

    logger.command('melos exec', withDollarSign: true);
    logger
        .child(targetStyle(execArgsString))
        .child('$runningLabel (in ${executablePackages.length} packages)')
        .newLine();
    if (prefixLogs) {
      logger.horizontalLine();
    }

    if (fingerprints != null) {
      await fingerprints.hashSources(executablePackagesList);
      for (final source in fingerprints.unmatchedSources) {
        logger.warning(
          'The sources glob "$source" does not match a file in any package.',
        );
      }
      for (final MapEntry(key: name, value: error)
          in fingerprints.unreadableSources.entries) {
        logger.warning(
          'The sources of $name could not be read, so the command runs in it '
          'regardless of whether they changed: $error',
        );
      }
    }

    final packageResults = Map.fromEntries(
      executablePackages.map(
        (package) => MapEntry(package.name, Completer<int?>()),
      ),
    );

    for (final packageLayer in sortedPackageLayers) {
      late final CancelableOperation<void> operation;
      final processOutputCancelToken = ProcessOutputCancelToken();

      operation = CancelableOperation.fromFuture(
        pool.forEach<Package, void>(packageLayer, (package) async {
          bool cancelIfFailedFast() {
            if (failFast && failures.isNotEmpty) {
              packageResults[package.name]?.complete();
              failures[package.name] = null;
              return true;
            }
            return false;
          }

          if (cancelIfFailedFast()) {
            return;
          }

          final group = useGroupBuffer ? package.name : null;

          final isUpToDate =
              fingerprints != null &&
              !force &&
              await fingerprints.isUpToDate(package);
          // The command can have failed in another package while the
          // fingerprint was being checked.
          if (cancelIfFailedFast()) {
            return;
          }

          if (isUpToDate) {
            packageResults[package.name]?.complete(0);
            skipped.add(package.name);
            if (!logger.isQuiet) {
              const skippedMessage = '(sources are unchanged)';
              if (prefixLogs) {
                logger.log(
                  '[${AnsiStyles.blue.bold(package.name)}]: '
                  '$skippedLabel $skippedMessage',
                );
              } else {
                logger
                  ..horizontalLine(group: group)
                  ..log(
                    AnsiStyles.bgBlack.bold.italic('${package.name}: ') +
                        AnsiStyles.bgBlack('$skippedLabel $skippedMessage'),
                    group: group,
                  );
              }
            }
            return;
          }

          if (fingerprints != null) {
            await fingerprints.commandStarted(package);
            if (cancelIfFailedFast()) {
              return;
            }
          }

          if (!prefixLogs) {
            logger
              ..horizontalLine(group: group)
              ..log(
                AnsiStyles.bgBlack.bold.italic('${package.name}:'),
                group: group,
              );
          }

          final commandExitCode = await _execForPackage(
            workspace,
            package,
            execArgs,
            prefixLogs: prefixLogs,
            extraEnvironment: additionalEnvironment,
            cancelToken: processOutputCancelToken,
            group: group,
          );
          final noTestsRan = commandExitCode == noTestsRanExitCode;
          final packageExitCode = noTestsRan ? 0 : commandExitCode;

          packageResults[package.name]?.complete(packageExitCode);

          final failed = packageExitCode > 0;
          if (failed) {
            // The failure is recorded before the sources are hashed again, so
            // that the command does not start in further packages when failing
            // fast.
            failures[package.name] = packageExitCode;
            if (failFast) {
              processOutputCancelToken.cancel();
              await operation.cancel();
              return;
            }
          }

          if (fingerprints != null) {
            await fingerprints.commandFinished(
              package,
              succeeded: packageExitCode == 0,
            );
          }

          if (failed) {
            return;
          }

          if (logger.isQuiet) {
            logger.discardGroup(package.name);
          } else if (!prefixLogs) {
            logger.log(
              AnsiStyles.bgBlack.bold.italic('${package.name}: ') +
                  AnsiStyles.bgBlack(
                    noTestsRan ? noTestsRanLabel : successLabel,
                  ),
              group: group,
            );
          }
        }).drain<void>(),
      );

      await operation.valueOrCancellation();
      if (failFast) {
        runningPids.forEach(Process.killPid);
      }
    }

    if (useGroupBuffer) {
      // Print the buffered output of every package, grouped per package and in
      // the order the packages started, with the failed packages last so that
      // they are easy to spot at the end of the log.
      await logger.flushGroupBufferIfNeed(lastGroups: failures.keys.toList());
    }

    final summaryLogger = failures.isEmpty ? logger : logger.essential;

    summaryLogger
      ..horizontalLine()
      ..newLine()
      ..command('melos exec', withDollarSign: true);

    final resultLogger = summaryLogger.child(targetStyle(execArgsString));

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

    if (skipped.isNotEmpty) {
      resultLogger.child(
        '$skippedLabel (in ${skipped.length} packages with unchanged sources)',
      );
    }

    final changedDependencies =
        await fingerprints?.findChangedDependencies() ?? const {};
    if (changedDependencies.isNotEmpty) {
      final affectedPackages = changedDependencies.entries
          .map((entry) => '  ${entry.key} (${entry.value.join(', ')})')
          .join('\n');
      logger
        ..newLine()
        ..warning(
          'The command changed files that match the sources in the '
          'dependencies of the following packages, after it had already '
          'started in these packages or skipped them:\n'
          '$affectedPackages\n'
          'The command will therefore run in these packages the next time. '
          'Specify "orderDependents" to run the command in the dependencies '
          'of a package first.',
        );
    }
  }
}
