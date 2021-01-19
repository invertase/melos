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
import 'dart:io';

import 'package:args/command_runner.dart' show Command;
import 'package:ansi_styles/ansi_styles.dart';
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
      'Initialize the workspace, link local packages together and install remaining package dependencies.';

  Future<int> _execInPackage(
      List<String> execArgs, String workingDirectory) async {
    final workingDirectoryPath = workingDirectory ?? Directory.current.path;
    final executable = Platform.isWindows ? 'cmd' : '/bin/sh';
    final filteredArgs = execArgs.map((arg) {
      var _arg = arg;

      // Remove empty args.
      if (_arg.trim().isEmpty) {
        return null;
      }

      // Attempt to make line continuations Windows & Linux compatible.
      if (_arg.trim() == r'\') {
        return Platform.isWindows ? _arg.replaceAll(r'\', '^') : _arg;
      }
      if (_arg.trim() == r'^') {
        return Platform.isWindows ? _arg : _arg.replaceAll('^', r'\');
      }

      return _arg;
    }).where((element) => element != null);

    final execProcess = await Process.start(
        executable, Platform.isWindows ? ['/C', '%MELOS_SCRIPT%'] : [],
        workingDirectory: workingDirectoryPath,
        includeParentEnvironment: true,
        environment: {
          'MELOS_SCRIPT': filteredArgs.join(' '),
        },
        runInShell: true);

    if (!Platform.isWindows) {
      // Pipe in the arguments to trigger the script to run.
      execProcess.stdin.writeln(filteredArgs.join(' '));
      // Exit the process with the same exit code as the previous command.
      execProcess.stdin.writeln('exit \$?');
    }

    var stdoutStream = execProcess.stdout;
    var stderrStream = execProcess.stderr;

    final List<int> processStdout = <int>[];
    final List<int> processStderr = <int>[];
    final Completer<int> processStdoutCompleter = Completer();
    final Completer<int> processStderrCompleter = Completer();

    stdoutStream.listen((List<int> event) {
      processStdout.addAll(event);
    }, onDone: () => processStdoutCompleter.complete());
    stderrStream.listen((List<int> event) {
      processStderr.addAll(event);
    }, onDone: () => processStderrCompleter.complete());

    await processStdoutCompleter.future;
    await processStderrCompleter.future;
    var exitCode = await execProcess.exitCode;

    if (exitCode > 0) {
      print('\n');
      stdout.add(processStdout);
      stderr.add(processStderr);
    }

    return exitCode;
  }

  @override
  void run() async {
    logger.stdout(AnsiStyles.yellow.bold('melos bootstrap'));
    logger.stdout('   └> ${AnsiStyles.cyan.bold(currentWorkspace.path)}\n');
    var successMessage = AnsiStyles.green('SUCCESS');
    logger.stdout('Bootstrapping project...');

    await Future.forEach(currentWorkspace.packages,
        (MelosPackage package) async {
      var pluginTemporaryPath =
          join(currentWorkspace.melosToolPath, package.pathRelativeToWorkspace);

      var generatedYamlMap = Map.from(package.yamlContents);

      currentWorkspace.packages.forEach((MelosPackage plugin) {
        var pluginPath = utils.relativePath(
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
      });

      var header = '# Generated file - do not modify or commit this file.';
      var generatedPubspecYamlString =
          '$header\n${toYamlString(generatedYamlMap)}';
      await File(utils.pubspecPathForDirectory(Directory(pluginTemporaryPath)))
          .create(recursive: true);
      await File(utils.pubspecPathForDirectory(Directory(pluginTemporaryPath)))
          .writeAsString(generatedPubspecYamlString);
    });

    var failed = false;
    var pool = Pool(5);
    List<String> pubGetArgs = ['pub', 'get'];
    List<String> execArgs = currentWorkspace.isFlutterWorkspace
        ? ['flutter', ...pubGetArgs]
        : [if (utils.isPubSubcommand()) 'dart', ...pubGetArgs];
    await pool.forEach<MelosPackage, void>(currentWorkspace.packages,
        (package) async {
      if (failed) {
        return;
      }

      var pluginTemporaryPath =
          join(currentWorkspace.melosToolPath, package.pathRelativeToWorkspace);
      final result = await _execInPackage(execArgs, pluginTemporaryPath);
      if (result > 0) {
        failed = true;
        logger.stdout('${AnsiStyles.bullet} ${AnsiStyles.bold(package.name)}');
        logger.stdout(
            '    └> ${AnsiStyles.blue(package.path.replaceAll(currentWorkspace.path, "."))}');
        logger.stdout(AnsiStyles.red(
            '       └> Failed to run "${execArgs.join(' ')}" in this package, see log output above for more information'));
        return;
      }
    }).drain();

    if (failed) {
      logger
          .stderr('Bootstrap failed, reason: pub get failed, see logs above.');
      exitCode = 1;
      return;
    }

    print('  > $successMessage');

    logger.stdout('Linking project packages');
    var intellijProject = IntellijProject.fromWorkspace(currentWorkspace);

    await currentWorkspace.linkPackages();
    currentWorkspace.clean(cleanPackages: false);

    if (currentWorkspace.config.generateIntellijIdeFiles) {
      await intellijProject.cleanFiles();
    }

    print('  > $successMessage');

    if (currentWorkspace.config.scripts.exists('postbootstrap')) {
      logger.stdout('Running postbootstrap script...\n');
      await MelosCommandRunner.instance.run(['run', 'postbootstrap']);
    }

    logger.stdout('\nPackages:');
    currentWorkspace.packages.forEach((package) {
      logger.stdout('${AnsiStyles.bullet} ${AnsiStyles.bold(package.name)}');
      logger.stdout(
          '    └> ${AnsiStyles.blue(package.path.replaceAll(currentWorkspace.path, "."))}');
    });
    logger.stdout(
        '\n -> ${currentWorkspace.packages.length} plugins bootstrapped');

    if (currentWorkspace.config.generateIntellijIdeFiles) {
      await IntellijProject.fromWorkspace(currentWorkspace).writeFiles();
    }
  }
}
