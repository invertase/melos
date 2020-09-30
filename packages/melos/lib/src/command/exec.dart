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
import 'package:ansi_styles/ansi_styles.dart';

import '../common/logger.dart';
import '../common/package.dart';
import '../common/workspace.dart';

class ExecCommand extends Command {
  @override
  final String name = 'exec';

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

  static Future<void> execInPackages(
    List<MelosPackage> packages,
    List<String> execArgs, {
    int concurrency = 5,
    bool failFast = false,
  }) async {
    var failures = <String, int>{};
    var pool = Pool(concurrency);
    String execArgsString = execArgs.join(' ');

    logger
        .stdout('${AnsiStyles.yellow('\$')} ${AnsiStyles.bold("melos exec")}');
    logger.stdout('   └> ${AnsiStyles.cyan.bold(execArgsString)}');
    logger.stdout(
        '       └> ${AnsiStyles.yellow.bold('RUNNING')} (in ${packages.length} packages)\n');

    await pool.forEach<MelosPackage, void>(packages, (package) {
      if (failFast && failures.isNotEmpty) {
        return Future.value(null);
      }
      if (concurrency == 1) {
        logger.stdout(AnsiStyles.bgBlack.bold.italic('${package.name}:'));
      }
      return package.exec(execArgs).then((result) async {
        if (result > 0) {
          failures[package.name] = result;
        } else if (concurrency == 1) {
          logger.stdout(AnsiStyles.bgBlack.bold.italic('${package.name}: ') +
              AnsiStyles.bold.green.bgBlack('SUCCESS'));
        }

        if (concurrency == 1) {
          logger.stdout('\n');
        }
      });
    }).drain();

    logger.stdout('');
    logger
        .stdout('${AnsiStyles.yellow('\$')} ${AnsiStyles.bold("melos exec")}');
    logger.stdout('   └> ${AnsiStyles.cyan.bold(execArgsString)}');

    if (failures.isNotEmpty) {
      logger.stdout(
          '       └> ${AnsiStyles.red.bold('FAILED')} (in ${failures.length} packages)');
      failures.keys.forEach((packageName) {
        logger.stdout(
            '           └> ${AnsiStyles.yellow(packageName)} (with exit code ${failures[packageName]})');
      });
      exitCode = 1;
    } else {
      logger.stdout('       └> ${AnsiStyles.green.bold('SUCCESS')}');
    }
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

    await execInPackages(currentWorkspace.packages, execArgs,
        concurrency: int.parse(argResults['concurrency'] as String),
        failFast: argResults['fail-fast'] as bool);
  }
}
