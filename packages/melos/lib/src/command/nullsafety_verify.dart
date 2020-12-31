/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

import 'dart:convert';
import 'dart:io';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:args/command_runner.dart' show Command;
import 'package:melos/src/command/bootstrap.dart';
import 'package:melos/src/command/clean.dart';
import 'package:path/path.dart';

import '../common/git.dart';
import '../common/logger.dart';
import '../common/nullsafety.dart';
import '../common/package.dart';
import '../common/utils.dart';
import '../common/workspace.dart';

class NullsafetyVerifyCommand extends Command {
  @override
  final String name = 'verify';

  @override
  final String description =
      'Verify that packages in this workspace are correctly setup and compatible with auto-nullsafety releases/migrations.';

  /// Track all modified files so we can revert them later.
  final Set<NullsafetyModifiedFile> _modifiedFiles = {};

  /// Track all modified packages for logging purposes.
  final Set<MelosPackage> _modifiedPackages = {};

  /// The user defined nullsafety configuration defined in melos.yaml.
  MelosWorkspaceNullsafetyConfig _nullsafetyConfig;

  /// Flag to gracefully abort further processing and finally revert all [_modifiedFiles].
  bool _abort = false;

  /// A possible exception that detailing an error that resulted in [_abort] being set to true.
  dynamic _capturedError;

  /// A user friendly exception hint that details what resulted in [_abort] being set to true.
  String _capturedErrorHint = '';

  NullsafetyVerifyCommand() {
    argParser.addFlag(
      'rollback',
      abbr: 'r',
      defaultsTo: true,
      negatable: true,
      help:
          'Roll back (via git) changes made to all files in the workspace during '
          'the verification process. It is recommended to leave this on, however '
          'for debug purposes you can set this to `--no-rollback` to leave the '
          'changes intact - to view any potential changes that will occur as part '
          'of migrating to nullsafety.',
    );
  }

  // Rollback changes to all modified files if revert enabled.
  Future<void> _rollbackFiles() async {
    bool rollback = argResults['rollback'] as bool;
    if (!rollback) return;

    if (_modifiedFiles.isEmpty) {
      return;
    }

    logger.stdout('');
    logger.stdout(
        'Rolling back local file changes in ${AnsiStyles.cyanBright(_modifiedFiles.length.toString())} files.');

    await Future.forEach(_modifiedFiles,
        (NullsafetyModifiedFile modifiedFile) async {
      logger.trace(
          'Reverting changes to file ${AnsiStyles.cyanBright(modifiedFile.path)}, in directory: ${AnsiStyles.greenBright(modifiedFile.workingDirectory)}');
      await gitRestore(
        modifiedFile.path,
        workingDirectory: modifiedFile.workingDirectory,
      );
    });

    // Bootstrap after reverting to ensure pub get is ran on previous files.
    await CleanCommand.clean().catchError(_catchError);
    await BootstrapCommand.bootstrapPubGet().catchError(_catchError);
    await BootstrapCommand.bootstrapLinkPackages().catchError(_catchError);
    logger.stdout('Rollback successful.');
  }

  Future<void> _abortAndRollbackChanges() async {
    _abort = true;
    await _rollbackFiles();
    logger.stdout('');
    if (_capturedErrorHint != null) {
      logger.stdout('${AnsiStyles.redBright('FAILED:')} $_capturedErrorHint');
    }
    if (_capturedError != null) {
      logger.stdout('');
      exitCode = 1;
      throw _capturedError;
    }
  }

  Future<void> _applyNullsafetyCodeMods() async {
    return Future.forEach(
      currentWorkspace.packages,
      (MelosPackage package) async {
        if (_abort) return;
        List<File> dartFiles = await Directory(package.path)
            .list(recursive: true, followLinks: false)
            .where((file) {
              return file.path.endsWith('.dart');
            })
            .map<File>((entity) => File(entity.path))
            .toList();

        int filesModifiedInPackage = 0;
        await Future.forEach(dartFiles, (File dartFile) async {
          CodeModType codeModType;
          try {
            codeModType = await applyNullsafetyCodeModsToFile(dartFile);
            if (codeModType != CodeModType.none) {
              _modifiedFiles
                  .add(NullsafetyModifiedFile(package.path, dartFile.path));
              _modifiedPackages.add(package);
              filesModifiedInPackage++;
              if (codeModType == CodeModType.stripTaggedCodeHasInvalidPair) {
                _abort = true;
                _capturedErrorHint =
                    'A Dart file in the package ${AnsiStyles.cyanBright(package.name)} contains an invalid remove '
                    'code start and end pair. Ensure each "melos-nullsafety-remove-start" '
                    'code comment is also paired with a "melos-nullsafety-remove-end" comment.\nFile: ${AnsiStyles.cyanBright(dartFile.path)}';
              }
            }
          } on FormatterException catch (formatException) {
            _abort = true;
            _capturedError = formatException;
            _capturedErrorHint =
                'An error occurred whilst trying to format a Dart file after '
                'Melos nullsafety code mods were applied. File: ${AnsiStyles.cyanBright(dartFile.path)}';
            logger.trace(formatException.toString());
          } on Exception catch (genericException) {
            _abort = true;
            _capturedError = genericException;
            _capturedErrorHint =
                'An error occurred whilst trying to apply Melos nullsafety code '
                'mods to a Dart file. File: ${AnsiStyles.cyanBright(dartFile.path)}';
            logger.trace(genericException.toString());
          }

          if (_abort) return;
          logger.trace(
              'File: ${AnsiStyles.cyanBright(dartFile.path)}, CodeModType: ${AnsiStyles.greenBright(codeModType.toString())}');
        });

        if (_abort) return;
        if (filesModifiedInPackage > 0) {
          logger.stdout(
              '    ${AnsiStyles.bold.greenBright('├')}  ${AnsiStyles.cyanBright(package.name)}: nullsafety code mods applied to ${AnsiStyles.greenBright(filesModifiedInPackage.toString())} files.');
        }
      },
    );
  }

  void _catchError(dynamic e) {
    _abort = true;
    _capturedError = e;
    _capturedErrorHint = 'An unknown error occurred: ';
  }

  Future<void> _validateNullsafetyMigrationRequirements() async {
    // Check is git repo and git is clean, e.g. no uncommitted changes.
    // Note internally we don't care about untracked files.
    if (!(await gitExists(workingDirectory: currentWorkspace.path)) ||
        !(await gitStatusIsClean(workingDirectory: currentWorkspace.path))) {
      _abort = true;
      _capturedErrorHint =
          'For this command to function correctly; your workspace must be a git '
          'repository and must have no tracked files with uncommitted changes.';
      return;
    }

    // Ensure melos.yaml exists (we can't use the default - 'no file' config).
    if (!_nullsafetyConfig.exists) {
      _abort = true;
      _capturedErrorHint =
          'A melos.yaml configuration file with nullsafety configuration is '
          'required for this command to function correctly.';
      return;
    }

    // Ensure "nullsafety" -> "environment" -> "sdk" is defined.
    if (_nullsafetyConfig.environmentSdkVersion == null) {
      _abort = true;
      _capturedErrorHint =
          'The Melos configuration "nullsafety" -> "environment" -> "sdk" is required for this '
          'command and must be defined in your melos.yaml configuration to continue.';
      return;
    }

    // TODO confirm if actually required?
    // If a Flutter workspace then ensure "nullsafety" -> "environment" -> "flutter" is defined.
    if (currentWorkspace.isFlutterWorkspace &&
        _nullsafetyConfig.environmentFlutterVersion == null) {
      _abort = true;
      _capturedErrorHint =
          'For Flutter workspaces: the Melos configuration "nullsafety" -> '
          '"environment" -> "flutter" is required for this command and must be '
          'defined in your melos.yaml configuration to continue.';
      return;
    }
  }

  Future<void> _applyEnvironmentConfig() async {
    // Update "environment.sdk" in melos.yaml.
    if (_nullsafetyConfig.environmentSdkVersion != null &&
        currentWorkspace.config.environmentSdkVersion != null) {
      _modifiedFiles.add(NullsafetyModifiedFile(
          currentWorkspace.path, currentWorkspace.pathToMelosFile));
      await setEnvironmentSdkVersionForYamlFile(
        _nullsafetyConfig.environmentSdkVersion,
        currentWorkspace.pathToMelosFile,
      ).catchError(_catchError);
      if (_abort) return;
    }

    // Update "environment.flutter" in melos.yaml.
    if (_nullsafetyConfig.environmentFlutterVersion != null &&
        currentWorkspace.config.environmentFlutterVersion != null) {
      _modifiedFiles.add(NullsafetyModifiedFile(
          currentWorkspace.path, currentWorkspace.pathToMelosFile));
      await setEnvironmentFlutterVersionForYamlFile(
        _nullsafetyConfig.environmentFlutterVersion,
        currentWorkspace.pathToMelosFile,
      ).catchError(_catchError);
    }
  }

  Future<void> _applyNullsafetyPackageVersions() {
    return Future.forEach(currentWorkspace.packages,
        (MelosPackage package) async {
      if (package.isPrivate) return;
      String nullsafetyVersion =
          nullsafetyVersionFromCurrentVersion(package.version).toString();
      logger.stdout(
        '    ${AnsiStyles.bold.greenBright('├')}  ${AnsiStyles.cyanBright(package.name)}: version change ${AnsiStyles.yellow(package.version.toString())} -> ${AnsiStyles.green(nullsafetyVersion.toString())}',
      );
      _modifiedFiles
          .add(NullsafetyModifiedFile(package.path, package.pathToPubspecFile));
      await package.setPubspecVersion(nullsafetyVersion);
      await Future.forEach(package.dependentsInWorkspace,
          (MelosPackage dependentPackage) {
        if (currentWorkspace.packages.contains(dependentPackage)) {
          _modifiedFiles.add(NullsafetyModifiedFile(
              dependentPackage.path, dependentPackage.pathToPubspecFile));
          return dependentPackage.setDependencyVersion(
            package.name,
            '^$nullsafetyVersion',
          );
        }
      });
    });
  }

  Future<void> _applyNullsafetyDependencyVersions() async {
    if (_nullsafetyConfig.shouldUpdateDependencies) {
      await Future.forEach(currentWorkspace.packages,
          (MelosPackage package) async {
        await Future.forEach(_nullsafetyConfig.dependencies.keys,
            (String dependencyName) {
          if (package.dependencies[dependencyName] != null ||
              package.devDependencies[dependencyName] != null) {
            String nullsafetyVersion =
                _nullsafetyConfig.dependencies[dependencyName];
            logger.stdout(
              '    ${AnsiStyles.bold.greenBright('├')}  ${AnsiStyles.cyanBright(package.name)}: dependency ${AnsiStyles.yellow(dependencyName)} updated to ${AnsiStyles.green(nullsafetyVersion)}',
            );
            return package.setDependencyVersion(
                dependencyName, _nullsafetyConfig.dependencies[dependencyName]);
          }
        });
      });
    }
  }

  Future<void> _applyNullsafetyPackageFilters() async {
    if (_nullsafetyConfig.shouldFilterPackages) {
      await currentWorkspace.loadPackagesWithFilters(
        scope: _nullsafetyConfig.filterPackageOptions[filterOptionScope]
            as List<String>,
        ignore: _nullsafetyConfig.filterPackageOptions[filterOptionIgnore]
            as List<String>,
        dirExists: _nullsafetyConfig.filterPackageOptions[filterOptionDirExists]
            as List<String>,
        fileExists: _nullsafetyConfig
            .filterPackageOptions[filterOptionFileExists] as List<String>,
        since:
            _nullsafetyConfig.filterPackageOptions[filterOptionSince] as String,
        skipPrivate: _nullsafetyConfig
            .filterPackageOptions[filterOptionNoPrivate] as bool,
        published: _nullsafetyConfig.filterPackageOptions[filterOptionPublished]
            as bool,
        hasFlutter:
            _nullsafetyConfig.filterPackageOptions[filterOptionFlutter] as bool,
        dependsOn: _nullsafetyConfig.filterPackageOptions[filterOptionDependsOn]
            as List<String>,
        noDependsOn: _nullsafetyConfig
            .filterPackageOptions[filterOptionNoDependsOn] as List<String>,
        override: true,
      );
    }
  }

  Future<void> _runAnalyzer() async {
    logger.stdout(
      '  ${AnsiStyles.bold.cyanBright('-')} Analyzing packages.',
    );

    await Future.forEach(currentWorkspace.packages,
        (MelosPackage package) async {
      if (_abort) return;
      List<String> toolExecArgs = [
        'dart',
        '--disable-analytics',
        'analyze',
        '.',
        '--fatal-infos',
      ];
      int exitCode = await package.exec(toolExecArgs, onlyOutputOnError: true);
      if (exitCode > 0) {
        logger.stdout(
          '    ${AnsiStyles.bold.redBright('✘')}  ${AnsiStyles.cyanBright(package.name)}: reported analyzer issues, see logs above.',
        );
        _abort = true;
        _capturedErrorHint =
            'Package ${AnsiStyles.cyanBright(package.name)} contains analyzer issues, see logs above for more information.';
      } else {
        logger.stdout(
          '    ${AnsiStyles.bold.greenBright('✔')}  ${AnsiStyles.cyanBright(package.name)}: no analyzer issues detected.',
        );
      }
    });
    if (_abort) {
      logger.stdout(
        '  ${AnsiStyles.bold.redBright('  └> FAILED')}: Some packages failed '
        'Dart code analysis, see log output above for more information. Alternatively '
        'you can run this step again with the `--no-rollback` flag to preserve changed files '
        'and use your IDE integration to view analyzer issues.',
      );
      await _abortAndRollbackChanges();
      return;
    }

    logger.stdout(
      '  ${AnsiStyles.bold.greenBright('  └> SUCCESS')}',
    );
    logger.stdout('');
  }

  Future<void> _bootstrapWorkspace() async {
    logger.stdout(
      '  ${AnsiStyles.bold.cyanBright('-')} Bootstrapping workspace.',
    );
    var didFailToBootstrap =
        await BootstrapCommand.bootstrapPubGet().catchError(_catchError);
    if (_abort || didFailToBootstrap) {
      await _abortAndRollbackChanges();
      logger.stdout(
        '  ${AnsiStyles.bold.redBright('  └> FAILED')}: Bootstrap failed, see log output above for more information.',
      );
      return;
    }
    await BootstrapCommand.bootstrapLinkPackages().catchError(_catchError);
    if (_abort) {
      await _abortAndRollbackChanges();
      logger.stdout(
        '  ${AnsiStyles.bold.redBright('  └> FAILED')}: Bootstrap failed, see log output above for more information.',
      );
      return;
    }
    logger.stdout('  ${AnsiStyles.bold.greenBright('  └> SUCCESS')}');
    logger.stdout('');
  }

  Future<void> _runDartMigrationTool() async {
    // Create the melos tool directory if it does not exist.
    // We use it to store json results of the migration tool.
    if (!Directory(currentWorkspace.melosToolPath).existsSync()) {
      Directory(currentWorkspace.melosToolPath).createSync(recursive: true);
    }

    await Future.forEach(currentWorkspace.packages,
        (MelosPackage package) async {
      if (_abort) return;

      String summaryJsonPath = joinAll([
        currentWorkspace.melosToolPath,
        'nullsafety_summary_${package.name}.json'
      ]);
      List<String> toolExecArgs = [
        'dart',
        'migrate',
        '--skip-import-check',
        '--ignore-errors',
        '--ignore-exceptions',
      ];

      int exitCode = await package.exec([
        ...toolExecArgs,
        '--apply-changes',
        '--summary=$summaryJsonPath',
      ], onlyOutputOnError: true);
      if (exitCode > 0) {
        _abort = true;
        _capturedErrorHint =
            'Package ${package.name} errored when running Dart migration tool, see logs above.';
        return;
      }

      File jsonFile = File(summaryJsonPath);
      bool jsonFileExists = await jsonFile.exists();
      if (!jsonFileExists) {
        _abort = true;
        _capturedErrorHint =
            'Package ${package.name} did not produce a migration summary json file when running the Dart migration tool.';
        return;
      }
      String jsonFileContents = await jsonFile.readAsString();
      Map jsonMap = jsonDecode(jsonFileContents) as Map;
      Map changesByPath = jsonMap['changes']['byPath'] as Map;

      Map<String, int> filesWithNoValidMigrationForNull = {};
      Map<String, int> filesWithConditionFalseInStrongMode = {};
      Map<String, int> filesWithNullAwareAssignmentUnnecessaryInStrongMode = {};
      changesByPath.forEach((key, value) {
        _modifiedFiles.add(NullsafetyModifiedFile(package.path, key as String));
        if (changesByPath[key]['noValidMigrationForNull'] != null) {
          filesWithNoValidMigrationForNull[key as String] =
              changesByPath[key]['noValidMigrationForNull'] as int;
        }
        if (changesByPath[key]['conditionFalseInStrongMode'] != null) {
          filesWithConditionFalseInStrongMode[key as String] =
              changesByPath[key]['conditionFalseInStrongMode'] as int;
        }
        if (changesByPath[key]['nullAwareAssignmentUnnecessaryInStrongMode'] !=
            null) {
          filesWithNullAwareAssignmentUnnecessaryInStrongMode[key as String] =
              changesByPath[key]['nullAwareAssignmentUnnecessaryInStrongMode']
                  as int;
        }
      });

      bool hasMigrationIssues = filesWithNoValidMigrationForNull.isNotEmpty ||
          filesWithConditionFalseInStrongMode.isNotEmpty ||
          filesWithNullAwareAssignmentUnnecessaryInStrongMode.isNotEmpty;
      if (hasMigrationIssues) {
        _abort = true;
        _capturedErrorHint =
            'One or more files in the package ${AnsiStyles.cyanBright(package.name)} contain nullsafety'
            ' migration issues (see logs above) - ensure all necessary nullsafety hints have been'
            ' added and try again. \n\nRun the following commands to view the interactive migration tool for this package:\n\n'
            '${AnsiStyles.gray('cd ${package.pathRelativeToWorkspace}')}\n'
            '${AnsiStyles.gray(toolExecArgs.join(' '))}\n';
        logger.stdout(
          '    ${AnsiStyles.bold.redBright('✘')}  ${AnsiStyles.cyanBright(package.name)} has the following migration issues:',
        );
      }

      if (filesWithNoValidMigrationForNull.isNotEmpty) {
        logger.stdout(
          '       ${AnsiStyles.bold.redBright(AnsiStyles.bullet)} ${AnsiStyles.bold.redBright('no valid nullsafety migration path')}:',
        );
        filesWithNoValidMigrationForNull.forEach((key, value) {
          logger.stdout(
            '         ${AnsiStyles.bold.redBright(AnsiStyles.bullet)}  ${AnsiStyles.cyanBright(key)} x $value.',
          );
        });
      }

      if (filesWithConditionFalseInStrongMode.isNotEmpty) {
        logger.stdout(
          '       ${AnsiStyles.bold.redBright(AnsiStyles.bullet)} ${AnsiStyles.bold.redBright('condition will always be false in strong checking mode (dead code)')}:',
        );
        filesWithConditionFalseInStrongMode.forEach((key, value) {
          logger.stdout(
            '         ${AnsiStyles.bold.redBright(AnsiStyles.bullet)}  ${AnsiStyles.cyanBright(key)} x $value.',
          );
        });
      }

      if (filesWithNullAwareAssignmentUnnecessaryInStrongMode.isNotEmpty) {
        logger.stdout(
          '       ${AnsiStyles.bold.redBright(AnsiStyles.bullet)} ${AnsiStyles.bold.redBright('null-aware assignment will be unnecessary in strong checking mode (dead code)')}:',
        );
        filesWithNullAwareAssignmentUnnecessaryInStrongMode
            .forEach((key, value) {
          logger.stdout(
            '         ${AnsiStyles.bold.redBright(AnsiStyles.bullet)}  ${AnsiStyles.cyanBright(key)} x $value.',
          );
        });
      }

      if (hasMigrationIssues) {
        logger.stdout(
          '  ${AnsiStyles.bold.redBright('  └> FAILED')}',
        );
        return;
      }

      logger.stdout(
        '    ${AnsiStyles.bold.greenBright('✔')}  ${AnsiStyles.cyanBright(package.name)}: migration tool reported ${changesByPath.keys.length} migrated files.',
      );
    });
  }

  @override
  void run() async {
    _nullsafetyConfig ??=
        MelosWorkspaceNullsafetyConfig(currentWorkspace.config);
    await _validateNullsafetyMigrationRequirements();
    if (_abort) {
      await _abortAndRollbackChanges();
      return;
    }

    // Clean workspace.
    logger.stdout(
      '  ${AnsiStyles.bold.cyanBright('-')} Cleaning workspace.',
    );
    await CleanCommand.clean().catchError(_catchError);
    if (_abort) {
      await _abortAndRollbackChanges();
      return;
    }
    logger.stdout('  ${AnsiStyles.bold.greenBright('  └> SUCCESS')}');
    logger.stdout('');

    // Apply package filtering.
    logger.stdout(
      '  ${AnsiStyles.bold.cyanBright('-')} Applying nullsafety package filtering options.',
    );
    var packagesLengthBeforeFilter =
        currentWorkspace.packages.length.toString();
    await _applyNullsafetyPackageFilters().catchError(_catchError);
    if (_abort) {
      await _abortAndRollbackChanges();
      return;
    }
    var packagesLengthAfterFilter = currentWorkspace.packages.length.toString();
    logger.stdout(
      '  ${AnsiStyles.bold.greenBright('  └> SUCCESS')}: Package filtering resulted in '
      '${AnsiStyles.cyanBright(packagesLengthAfterFilter)} out of '
      '${AnsiStyles.cyanBright(packagesLengthBeforeFilter)} packages being selected.',
    );
    logger.stdout('');

    // Bootstrap the workspace now that filters have been applied.
    await _bootstrapWorkspace();
    if (_abort) return;

    // Pre-migration check to verify dart analyze passes with current changes.
    await _runAnalyzer();
    if (_abort) return;

    // Apply Melos nullsafety code mods.
    logger.stdout(
        '  ${AnsiStyles.bold.cyanBright('-')} Applying Melos nullsafety code mods to packages.');
    await _applyNullsafetyCodeMods().catchError(_catchError);
    if (_abort) {
      await _abortAndRollbackChanges();
      return;
    }
    logger.stdout(
        '  ${AnsiStyles.bold.greenBright('  └> SUCCESS')}: Nullsafety code mods '
        'successfully applied to ${AnsiStyles.cyanBright(
      _modifiedFiles.length.toString(),
    )} files in ${AnsiStyles.cyanBright(_modifiedPackages.length.toString())} packages.');
    logger.stdout('');

    // Apply defined nullsafety package versions to each package pubspec.yaml.
    logger.stdout(
        '  ${AnsiStyles.bold.cyanBright('-')} Applying nullsafety versioning for workspace packages and their dependencies.');
    // Set package versions to current version & add -nullsafety.
    await _applyNullsafetyDependencyVersions().catchError(_catchError);
    if (_abort) {
      await _abortAndRollbackChanges();
      return;
    }
    // Set package dependencies to match any defined in config.nullsafety.package.
    await _applyNullsafetyPackageVersions().catchError(_catchError);
    if (_abort) {
      await _abortAndRollbackChanges();
      return;
    }
    logger.stdout(
      '  ${AnsiStyles.bold.greenBright('  └> SUCCESS')}: Versions '
      'have been updated in ${AnsiStyles.cyanBright(_modifiedPackages.length.toString())} packages.',
    );
    logger.stdout('');

    // Bootstrap workspace so new packages and versions are updated.
    await _bootstrapWorkspace().catchError(_catchError);
    if (_abort) return;

    // Run Dart migration tool.
    logger.stdout(
        '  ${AnsiStyles.bold.cyanBright('-')} Running Dart nullsafety migration tool.');
    await _runDartMigrationTool().catchError(_catchError);
    if (_abort) {
      await _abortAndRollbackChanges();
      return;
    }
    logger.stdout('  ${AnsiStyles.bold.greenBright('  └> SUCCESS')}');
    logger.stdout('');

    // Apply environment versions to melos.yaml
    await _applyEnvironmentConfig().catchError(_catchError);
    if (_abort) {
      await _abortAndRollbackChanges();
      return;
    }

    // Bootstrap workspace so migrations and melos environment updates are picked up.
    await _bootstrapWorkspace();
    if (_abort) return;

    // Post-migration check to verify dart analyze passes with all new changes.
    await _runAnalyzer();
    if (_abort) return;

    // Finally, revert all changes if requested.
    await _rollbackFiles();

    logger.stdout('');
    logger.stdout(
        '${AnsiStyles.bold.greenBright('SUCCESS')}: all packages are compatible for automated nullsafety package building.');
  }
}
