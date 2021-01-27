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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:args/command_runner.dart' show Command;
import 'package:path/path.dart';
import 'package:pool/pool.dart';
import 'package:yamlicious/yamlicious.dart';

import '../command_runner.dart';
import '../common/intellij_project.dart';
import '../common/logger.dart';
import '../common/package.dart';
import '../common/utils.dart' as utils;
import '../common/workspace.dart';

class BootstrapCommand extends Command {
  @override
  final String name = 'bootstrap';

  @override
  final List<String> aliases = ['bs'];

  @override
  final String description =
      'Initialize the workspace, link local packages together and install remaining package dependencies. Supports all package filtering options.';

  bool _pubGetFailed = false;

  final List<Process> _runningProcesses = [];

  Future<bool> _runPubGetForPackage(MelosPackage package) async {
    final pubGetArgs = ['pub', 'get'];
    final execArgs = currentWorkspace.isFlutterWorkspace
        ? ['flutter', ...pubGetArgs]
        : [if (utils.isPubSubcommand()) 'dart', ...pubGetArgs];
    final executable = Platform.isWindows ? 'cmd' : '/bin/sh';
    final pluginTemporaryPath =
        join(currentWorkspace.melosToolPath, package.pathRelativeToWorkspace);
    final execProcess = await Process.start(
        executable, Platform.isWindows ? ['/C', '%MELOS_SCRIPT%'] : [],
        workingDirectory: pluginTemporaryPath,
        includeParentEnvironment: true,
        environment: {
          utils.envKeyMelosTerminalWidth: utils.terminalWidth.toString(),
          'MELOS_SCRIPT': execArgs.join(' '),
        },
        runInShell: true);
    _runningProcesses.add(execProcess);

    if (!Platform.isWindows) {
      // Pipe in the arguments to trigger the script to run.
      execProcess.stdin.writeln(execArgs.join(' '));
      // Exit the process with the same exit code as the previous command.
      execProcess.stdin.writeln(r'exit $?');
    }

    final stdoutStream = execProcess.stdout;
    final stderrStream = execProcess.stderr;
    final processStdout = <int>[];
    final processStderr = <int>[];
    final processStdoutCompleter = Completer();
    final processStderrCompleter = Completer();

    stdoutStream.listen(processStdout.addAll,
        onDone: processStdoutCompleter.complete);
    stderrStream.listen(processStderr.addAll,
        onDone: processStderrCompleter.complete);

    await processStdoutCompleter.future;
    await processStderrCompleter.future;

    final exitCode = await execProcess.exitCode;
    _runningProcesses.remove(execProcess);

    if (_pubGetFailed) {
      return true;
    }

    if (exitCode > 0) {
      logger.stdout('');
      logger.stdout(AnsiStyles.gray('-' * utils.terminalWidth));
      var processStdOutString = utf8.decoder.convert(processStdout);
      var processStdErrString = utf8.decoder.convert(processStderr);

      processStdOutString = processStdOutString
          .split('\n')
          // We filter these out as they can be quite spammy. This happens
          // as we run multiple pub gets in parrallel.
          .where((line) => !line.contains(
              'Waiting for another flutter command to release the startup lock'))
          // Remove empty lines to reduce logging.
          .where((line) => line.trim().isNotEmpty)
          // Highlight the current package name in any logs.
          .map((line) => line.replaceAll(
              '${package.name}.', '${AnsiStyles.cyan(package.name)}.'))
          .toList()
          .join('\n');

      processStdErrString = processStdErrString
          .split('\n')
          // We filter these out as they can be quite spammy. This happens
          // as we run multiple pub gets in parrallel.
          .where((line) => !line.contains(
              'Waiting for another flutter command to release the startup lock'))
          // Remove empty lines to reduce logging.
          .where((line) => line.trim().isNotEmpty)
          // Highlight the current package name in any logs.
          .map((line) => line.replaceAll(
              '${package.name} ', '${AnsiStyles.cyan(package.name)} '))
          // // Highlight other local workspace packages in the logs.
          .map((line) {
            var lineWithWorkspacePackagesHighlighted = line;
            for (final workspacePackage in currentWorkspace.packages) {
              if (workspacePackage.name == package.name) continue;
              lineWithWorkspacePackagesHighlighted =
                  lineWithWorkspacePackagesHighlighted.replaceAll(
                      '${workspacePackage.name} ',
                      '${AnsiStyles.yellowBright(workspacePackage.name)} ');
            }
            return lineWithWorkspacePackagesHighlighted;
          })
          .toList()
          .join('\n');

      logger.stdout(processStdOutString);
      logger.stderr(processStdErrString);

      logger
          .stdout('${AnsiStyles.bullet} ${AnsiStyles.bold.cyan(package.name)}');
      logger.stdout(
          '    └> ${AnsiStyles.blue(package.path.replaceAll(currentWorkspace.path, "."))}');
      logger.stdout(
          '    └> ${AnsiStyles.red('Failed to run "${execArgs.join(' ')}" in this package.')}');
      logger.stdout(AnsiStyles.gray('-' * utils.terminalWidth));
    }

    return exitCode > 0;
  }

  @override
  Future<void> run() async {
    final successMessage = AnsiStyles.green('SUCCESS');
    final pubCommandForLogging =
        "${currentWorkspace.isFlutterWorkspace ? "flutter " : ""}pub get";
    logger.stdout(AnsiStyles.yellow.bold('melos bootstrap'));
    logger.stdout('   └> ${AnsiStyles.cyan.bold(currentWorkspace.path)}\n');

    logger.stdout('Running "$pubCommandForLogging" in workspace packages...');
    if (!utils.isCI && currentWorkspace.packages.length > 20) {
      logger.stdout(AnsiStyles.yellow(
          'Note: this may take a while in large workspaces such as this one.'));
    }

    // As melos boostrap builds a 1-1 mirror of the packages tree in the
    // .melos_tool directory we need to use unscoped packages here so as to
    // preserve any local 'dependencies' or 'depedency_overrides' that packages
    // in `currentWorkspace.packages` may be referencing by relative paths.
    await Future.forEach(currentWorkspace.packagesNoScope,
        (MelosPackage package) async {
      final pluginTemporaryPath =
          join(currentWorkspace.melosToolPath, package.pathRelativeToWorkspace);

      final generatedYamlMap = Map.from(package.yamlContents);

      // As melos boostrap builds a 1-1 mirror of the packages tree in the
      // .melos_tool directory we need to use unscoped packages here so as to
      // preserve any local 'dependencies' or 'depedency_overrides' that packages
      // in `currentWorkspace.packages` may be referencing by relative paths.
      for (final plugin in currentWorkspace.packagesNoScope) {
        final pluginPath = utils.relativePath(
          join(currentWorkspace.melosToolPath, plugin.pathRelativeToWorkspace),
          pluginTemporaryPath,
        );

        if (!generatedYamlMap.containsKey('dependency_overrides')) {
          generatedYamlMap['dependency_overrides'] = {};
        } else {
          generatedYamlMap['dependency_overrides'] =
              Map.from(generatedYamlMap['dependency_overrides'] as Map);
        }

        if (generatedYamlMap.containsKey('dependencies')) {
          generatedYamlMap['dependencies'] =
              Map.from(generatedYamlMap['dependencies'] as Map);
        }

        if (generatedYamlMap.containsKey('dev_dependencies')) {
          generatedYamlMap['dev_dependencies'] =
              Map.from(generatedYamlMap['dev_dependencies'] as Map);
        }

        if (package.dependencyOverrides.containsKey(plugin.name)) {
          generatedYamlMap['dependency_overrides'][plugin.name] = {
            'path': pluginPath,
          };
        }

        if (package.dependencies.containsKey(plugin.name)) {
          generatedYamlMap['dependencies'][plugin.name] = {
            'path': pluginPath,
          };
          generatedYamlMap['dependency_overrides'][plugin.name] = {
            'path': pluginPath,
          };
        }

        if (package.devDependencies.containsKey(plugin.name)) {
          generatedYamlMap['dev_dependencies'][plugin.name] = {
            'path': pluginPath,
          };
          generatedYamlMap['dependency_overrides'][plugin.name] = {
            'path': pluginPath,
          };
        }

        if (package.dependencyOverrides.containsKey(plugin.name)) {
          generatedYamlMap['dependency_overrides'][plugin.name] = {
            'path': pluginPath,
          };
        }
      }

      const header = '# Generated file - do not commit this file.';
      final generatedPubspecYamlString =
          '$header\n${toYamlString(generatedYamlMap)}';

      await File(utils.pubspecPathForDirectory(Directory(pluginTemporaryPath)))
          .create(recursive: true);
      await File(utils.pubspecPathForDirectory(Directory(pluginTemporaryPath)))
          .writeAsString(generatedPubspecYamlString);
    });

    final pool = Pool(utils.isCI ? 1 : 5);
    // As noted in previous `packages` loops/forEach blocks above re using
    // packagesNoScope, however in this instance we explictly want only run
    // pub get in the packages the user has specified (currentWorkspace.packages).
    // Previous loops/forEach blocks above will have preserved pubspec.yaml
    // files for packages the user has excluded from this boostrap/workspace,
    // which will allow non-excluded packages to still reference to them by path,
    // e.g. using 'depedency_overrides'.
    await pool.forEach<MelosPackage, void>(currentWorkspace.packages,
        (package) async {
      if (_pubGetFailed) {
        return;
      }

      final packagePubGetFailed = await _runPubGetForPackage(package);
      if (packagePubGetFailed && !_pubGetFailed) {
        _pubGetFailed = true;
        for (final process in _runningProcesses) {
          process.kill(ProcessSignal.sigterm);
        }
        currentWorkspace.clean(cleanPackages: false);
        logger.stderr(AnsiStyles.red(
            '\nBootstrap failed: "$pubCommandForLogging" failed in one of your workspace packages.'));
        exitCode = 1;
        exit(exitCode);
      }

      if (!_pubGetFailed) {
        logger.stdout(
            '  ${AnsiStyles.greenBright('✓')} ${AnsiStyles.bold(package.name)}');
        logger.stdout(
            '     └> ${AnsiStyles.blue(package.path.replaceAll(currentWorkspace.path, "."))}');
      }
    }).drain();

    logger.stdout('');
    logger.stdout('Linking workspace packages...');
    await currentWorkspace.linkPackages();
    currentWorkspace.clean(cleanPackages: false);
    logger.stdout('  > $successMessage');

    if (currentWorkspace.config.generateIntellijIdeFiles) {
      logger.stdout('');
      logger.stdout('Generating IntelliJ IDE files...');
      final intellijProject = IntellijProject.fromWorkspace(currentWorkspace);
      await intellijProject.clean();
      await intellijProject.generate();
      logger.stdout('  > $successMessage');
    }

    if (currentWorkspace.config.scripts.exists('postbootstrap')) {
      logger.stdout('Running postbootstrap script...\n');
      await MelosCommandRunner.instance.run(['run', 'postbootstrap']);
    }

    logger.stdout(
        '\n -> ${currentWorkspace.packages.length} plugins bootstrapped');
  }
}
