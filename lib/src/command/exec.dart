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

import 'package:args/command_runner.dart' show Command;
import 'package:pool/pool.dart' show Pool;

import '../common/logger.dart';
import '../common/package.dart';
import '../common/workspace.dart';

class ExecCommand extends Command {
  @override
  final String name = 'exec';

  @override
  final List<String> aliases = ['e'];

  @override
  final String description =
      'Execute an arbitrary command in each package. Supports all package filtering options.';

  ExecCommand() {
    argParser.addOption('concurrency', defaultsTo: '5', abbr: 'c');
    argParser.addFlag('fail-fast',
        abbr: 'f',
        defaultsTo: false,
        negatable: true,
        help:
            'Whether exec should fail fast and not execute the script in further packages if the script fails in a individual package.');
  }

  @override
  void run() async {
    final execArgs = argResults.rest;

    if (execArgs.isEmpty) {
      print(description);
      print(argParser.usage);
      exitCode = 1;
      return;
    }

    var execArgsString = execArgs.join(' ');

    logger.stdout(
        '${logger.ansi.yellow}\$${logger.ansi.noColor} ${logger.ansi.emphasized("melos exec ${argResults.arguments[0]}")}');
    logger.stdout(
        '   └> ${logger.ansi.cyan}${logger.ansi.emphasized(execArgsString)}${logger.ansi.noColor}');
    logger.stdout(
        '       └> ${logger.ansi.yellow}${logger.ansi.emphasized('RUNNING')}${logger.ansi.noColor} (in ${currentWorkspace.packages.length} packages)\n');

    var failures = <String, int>{};
    var pool = Pool(int.parse(argResults['concurrency'] as String));

    await pool.forEach<MelosPackage, void>(currentWorkspace.packages,
        (package) {
      if (argResults['fail-fast'] == true && failures.isNotEmpty) {
        return Future.value(null);
      }
      return package.exec(execArgs).then((result) async {
        if (result > 0) {
          failures[package.name] = result;
        }
      });
    }).drain();

    logger.stdout('');
    logger.stdout(
        '${logger.ansi.yellow}\$${logger.ansi.noColor} ${logger.ansi.emphasized("melos exec ${argResults.arguments[0]}")}');
    logger.stdout(
        '   └> ${logger.ansi.cyan}${logger.ansi.emphasized(execArgsString)}${logger.ansi.noColor}');

    if (failures.isNotEmpty) {
      logger.stdout(
          '       └> ${logger.ansi.red}${logger.ansi.emphasized('FAILED')}${logger.ansi.noColor} (in ${failures.length} packages)');
      failures.keys.forEach((packageName) {
        logger.stdout(
            '           └> ${logger.ansi.yellow}$packageName${logger.ansi.noColor} (with exit code ${failures[packageName]})');
      });
      exitCode = 1;
    } else {
      logger.stdout(
          '       └> ${logger.ansi.green}${logger.ansi.emphasized('SUCCESS')}${logger.ansi.noColor}');
    }
  }
}
