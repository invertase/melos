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

import 'dart:io';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:args/command_runner.dart' show Command;

import '../command_runner.dart';
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
    logger.stdout('Bootstrapping workspace after reverting changes...');
    currentWorkspace = null;
    await MelosCommandRunner.instance.run(['clean']);
    await MelosCommandRunner.instance.run(['bootstrap']);
    logger.stdout('');
    logger.stdout('Rollback successful.');
  }

  Future<void> _abortAndRollbackChanges() async {
    await _rollbackFiles();
    logger.stdout('');
    logger.stdout(_capturedErrorHint);
    if (_capturedError != null) {
      logger.stdout('');
      logger.stdout(_capturedError.toString());
    }
    exitCode = 1;
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
        override: true,
      );
    }
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

    var packagesLengthBeforeFilter =
        currentWorkspace.packages.length.toString();
    logger.stdout(
      '  ${AnsiStyles.bold.cyanBright('0)')} Applying Melos nullsafety package filtering options.',
    );
    await MelosCommandRunner.instance.run(['clean']).catchError(_catchError);
    if (_abort || exitCode == 1) {
      await _abortAndRollbackChanges();
      return;
    }
    await _applyNullsafetyPackageFilters().catchError(_catchError);
    if (_abort) {
      await _abortAndRollbackChanges();
      return;
    }
    await MelosCommandRunner.instance
        .run(['bootstrap']).catchError(_catchError);
    if (_abort || exitCode == 1) {
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

    // --------------
    //     Step 1
    // --------------
    // Apply Melos nullsafety code mods.
    logger.stdout(
        '  ${AnsiStyles.bold.cyanBright('1)')} Applying Melos nullsafety code mods to packages.');
    await _applyNullsafetyCodeMods().catchError(_catchError);
    if (_abort) {
      await _abortAndRollbackChanges();
      return;
    }
    // 1) Successful.
    logger.stdout(
        '  ${AnsiStyles.bold.greenBright('  └> SUCCESS')}: Nullsafety code mods '
        'successfully applied to ${AnsiStyles.cyanBright(
      _modifiedFiles.length.toString(),
    )} files in ${AnsiStyles.cyanBright(_modifiedPackages.length.toString())} packages.');

    // --------------
    //     Step 2
    // --------------
    // Apply defined nullsafety package versions to each package pubspec.yaml.
    logger.stdout('');
    logger.stdout(
        '  ${AnsiStyles.bold.cyanBright('2)')} Applying nullsafety versioning for workspace packages and their dependencies.');
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
    // 2) Successful.
    logger.stdout(
      '  ${AnsiStyles.bold.greenBright('  └> SUCCESS')}: Versions '
      'have been updated in ${AnsiStyles.cyanBright(_modifiedPackages.length.toString())} packages.',
    );

    // --------------
    //     Step 3
    // --------------
    // Bootstrap workspace.
    logger.stdout('');
    logger.stdout(
        '  ${AnsiStyles.bold.cyanBright('3)')} Bootstrapping workspace to fetch new dependencies.');
    await MelosCommandRunner.instance
        .run(['bootstrap']).catchError(_catchError);
    if (_abort || exitCode == 1) {
      await _abortAndRollbackChanges();
      return;
    }
    // 3) Successful.
    logger.stdout(
        '  ${AnsiStyles.bold.greenBright('  └> SUCCESS')}: Bootstrap successful.');

    // TODO
    // TODO
    // TODO
    // TODO
    await MelosCommandRunner.instance.run([
      'exec',
      '-c 1',
      '--fail-fast',
      '--',
      'dart migrate --apply-changes --skip-import-check --ignore-errors --ignore-exceptions'
      //  --skip-import-check
    ]).catchError(_catchError);
    if (_abort || exitCode == 1) {
      await _abortAndRollbackChanges();
      return;
    }
    // Apply environment versions to melos.yaml
    await _applyEnvironmentConfig().catchError(_catchError);
    if (_abort) {
      await _abortAndRollbackChanges();
      return;
    }
    await MelosCommandRunner.instance
        .run(['bootstrap']).catchError(_catchError);
    if (_abort || exitCode == 1) {
      await _abortAndRollbackChanges();
      return;
    }

    // TODO
    // TODO
    // TODO
    // TODO
    // TODO 6) `dart pub outdated --mode=null-safety --json` to confirm no packages are missing nullsafety upgrades
    // TODO 7) verify with analyzer, use MELOS_PACKAGES env variable to limit scope
    // TODO 8) Run migration via `dart migrate --summary=summary.json --skip-import-check`
    // TODO 9) verify with analyzer again, use MELOS_PACKAGES env variable to limit scope

    // Finally, revert all changes if requested.
    await _rollbackFiles();
  }
}
