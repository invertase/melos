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

import 'package:path/path.dart' show relative, normalize, windows, joinAll;
import 'package:yaml/yaml.dart';
import 'package:ansi_styles/ansi_styles.dart';
import 'package:prompts/prompts.dart' as prompts;

import '../../version.dart';
import 'logger.dart';

var _didLogRmWarning = false;

bool promptBool() {
  logger.stdout('');
  return prompts.getBool('Continue?',
      appendYesNo: true, chevron: true, defaultsTo: false, color: true);
}

bool get isCI {
  var keys = Platform.environment.keys;
  return keys.contains('CI') ||
      keys.contains('CONTINUOUS_INTEGRATION') ||
      keys.contains('BUILD_NUMBER') ||
      keys.contains('RUN_ID');
}

String getMelosRoot() {
  if (Platform.script.path.contains('global_packages')) {
    return joinAll([
      File.fromUri(Platform.script).parent.parent.parent.parent.path,
      'hosted',
      'pub.dartlang.org',
      'melos-$melosVersion'
    ]);
  }
  return File.fromUri(Platform.script).parent.parent.path;
}

String getAndroidSdkRoot() {
  var possibleSdkRoot = Platform.environment['ANDROID_SDK_ROOT'];
  if (possibleSdkRoot == null) {
    logger.stderr(
        "Android SDK root could not be found, ensure you've set the ANDROID_SDK_ROOT environment variable.");
    return '';
  }
  return possibleSdkRoot;
}

// TODO not Windows compatible
String getFlutterSdkRoot() {
  var result = Process.runSync('which', ['flutter']);
  var possiblePath = result.stdout.toString();
  if (!possiblePath.contains('bin/flutter')) {
    logger.stderr('Flutter SDK could not be found.');
    return null;
  }
  return File(result.stdout as String).parent.parent.path;
}

Map loadYamlFileSync(String path) {
  var file = File(path);
  if (file?.existsSync() == true) {
    return loadYaml(file.readAsStringSync()) as Map;
  }
  return null;
}

Future<Map> loadYamlFile(String path) async {
  var file = File(path);
  if (await file?.exists() == true) {
    return loadYaml(await file.readAsString()) as Map;
  }
  return null;
}

String melosYamlPathForDirectory(Directory directory) {
  return joinAll([directory.path, 'melos.yaml']);
}

String melosStatePathForDirectory(Directory directory) {
  return joinAll([directory.path, '.melos']);
}

String pubspecPathForDirectory(Directory directory) {
  return joinAll([directory.path, 'pubspec.yaml']);
}

String relativePath(String path, String from) {
  if (Platform.isWindows) {
    return windows.normalize(path).replaceAll(r'\', r'\\');
  }
  return normalize(relative(path, from: from));
}

String listAsPaddedTable(List<List<String>> list, {int paddingSize = 1}) {
  Map<int, int> maxColumnSizes = {};
  List<String> output = [];
  list.forEach((cells) {
    var i = 0;
    cells.forEach((cell) {
      if (maxColumnSizes[i] == null ||
          maxColumnSizes[i] < AnsiStyles.strip(cell).length) {
        maxColumnSizes[i] = AnsiStyles.strip(cell).length;
      }
      i++;
    });
  });
  list.forEach((cells) {
    var i = 0;
    var row = '';
    cells.forEach((cell) {
      var colWidth = maxColumnSizes[i] + paddingSize;
      var cellWidth = AnsiStyles.strip(cell).length;
      var padding = colWidth - cellWidth;
      if (padding < paddingSize) padding = paddingSize;
      row += '$cell${List.filled(padding, ' ').join()}';
      i++;
    });
    output.add(row);
  });
  return output.join('\n');
}

/// Simple check to see if the [Directory] qualifies as a plugin repository.
bool isWorkspaceDirectory(Directory directory) {
  var melosYamlPath = melosYamlPathForDirectory(directory);
  return FileSystemEntity.isFileSync(melosYamlPath);
}

bool isPackageDirectory(Directory directory) {
  var pluginYamlPath = pubspecPathForDirectory(directory);
  return FileSystemEntity.isFileSync(pluginYamlPath);
}

Future<int> startProcess(List<String> execArgs,
    {String prefix,
    Map<String, String> environment,
    String workingDirectory,
    bool onlyOutputOnError = false}) async {
  final environmentVariables = environment ?? {};
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

    // Inject Melos variables if any.
    environment.forEach((key, value) {
      _arg = _arg.replaceAll('\$$key', value);
      _arg = _arg.replaceAll(key, value);
    });

    return _arg;
  }).where((element) => element != null);

  // TODO This is just a temporary workaround to keep FlutterFire working on Windows
  // TODO until all the run scripts have been updated in its melos.yaml file.
  if (filteredArgs.toList()[0] == 'rm' && Platform.isWindows) {
    if (!_didLogRmWarning) {
      print(
          '> Warning: skipped executing a script as "rm" is not supported on Windows.');
      _didLogRmWarning = true;
    }
    return 0;
  }
  if (filteredArgs.toList()[0] == 'cp' && Platform.isWindows) {
    if (!_didLogRmWarning) {
      print(
          '> Warning: skipped executing a script as "cp" is not supported on Windows.');
      _didLogRmWarning = true;
    }
    return 0;
  }

  final execProcess = await Process.start(
      executable, Platform.isWindows ? ['/C', '%MELOS_SCRIPT%'] : [],
      workingDirectory: workingDirectoryPath,
      includeParentEnvironment: true,
      environment: {
        ...environmentVariables,
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

  if (prefix != null && prefix.isNotEmpty) {
    final pluginPrefixTransformer =
        StreamTransformer<String, String>.fromHandlers(
            handleData: (String data, EventSink sink) {
      final lineSplitter = LineSplitter();
      var lines = lineSplitter.convert(data);
      lines = lines
          .map((line) => '$prefix$line${line.contains('\n') ? '' : '\n'}')
          .toList();
      sink.add(lines.join(''));
    });

    stdoutStream = execProcess.stdout
        .transform<String>(utf8.decoder)
        .transform<String>(pluginPrefixTransformer)
        .transform<List<int>>(utf8.encoder);

    stderrStream = execProcess.stderr
        .transform<String>(utf8.decoder)
        .transform<String>(pluginPrefixTransformer)
        .transform<List<int>>(utf8.encoder);
  }

  final List<int> processStdout = <int>[];
  final List<int> processStderr = <int>[];
  final Completer<int> processStdoutCompleter = Completer();
  final Completer<int> processStderrCompleter = Completer();

  stdoutStream.listen((List<int> event) {
    processStdout.addAll(event);
    if (!onlyOutputOnError) {
      stdout.add(event);
    }
  }, onDone: () => processStdoutCompleter.complete());
  stderrStream.listen((List<int> event) {
    processStderr.addAll(event);
    if (!onlyOutputOnError) {
      stderr.add(event);
    }
  }, onDone: () => processStderrCompleter.complete());

  await processStdoutCompleter.future;
  await processStderrCompleter.future;
  var exitCode = await execProcess.exitCode;

  if (onlyOutputOnError && exitCode > 0) {
    stdout.add(processStdout);
    stderr.add(processStderr);
  }

  return exitCode;
}

bool isPubSubcommand() {
  try {
    return Process.runSync('pub', ['--version']).exitCode != 0;
  } on ProcessException catch (e) {
    return true;
  }
}
