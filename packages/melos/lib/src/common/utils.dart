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
import 'package:path/path.dart' show relative, normalize, windows, joinAll;
import 'package:prompts/prompts.dart' as prompts;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import '../../version.g.dart';

const filterOptionScope = 'scope';
const filterOptionIgnore = 'ignore';
const filterOptionDirExists = 'dir-exists';
const filterOptionFileExists = 'file-exists';
const filterOptionSince = 'since';
const filterOptionNullsafety = 'nullsafety';
const filterOptionNoPrivate = 'no-private';
const filterOptionPublished = 'published';
const filterOptionFlutter = 'flutter';
const filterOptionDependsOn = 'depends-on';
const filterOptionNoDependsOn = 'no-depends-on';

// MELOS_PACKAGES environment variable is a comma delimited list of
// package names - used instead of filters if it is present.
// This can be user defined or can come from package selection in `melos run`.
const envKeyMelosPackages = 'MELOS_PACKAGES';

const envKeyMelosTerminalWidth = 'MELOS_TERMINAL_WIDTH';

int get terminalWidth {
  if (Platform.environment.containsKey(envKeyMelosTerminalWidth)) {
    return int.tryParse(
          Platform.environment[envKeyMelosTerminalWidth],
          radix: 10,
        ) ??
        80;
  }

  if (stdout.hasTerminal) {
    return stdout.terminalColumns;
  }

  return 80;
}

String get currentDartVersion {
  return Version.parse(Platform.version.split(' ')[0]).toString();
}

String get nextDartMajorVersion {
  return Version.parse(currentDartVersion).nextMajor.toString();
}

String promptInput(String message, {String defaultsTo}) {
  return prompts.get(message, defaultsTo: defaultsTo);
}

bool promptBool({String message = 'Continue?', bool defaultsTo = false}) {
  return prompts.getBool(message, defaultsTo: defaultsTo);
}

bool get isCI {
  final keys = Platform.environment.keys;
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

  // This allows us to use melos on itself during development.
  if (Platform.script.path.contains('melos_dev.dart')) {
    return joinAll([
      File.fromUri(Platform.script).parent.parent.path,
      'packages',
      'melos'
    ]);
  }

  return File.fromUri(Platform.script).parent.parent.path;
}

Map loadYamlFileSync(String path) {
  final file = File(path);
  if (file.existsSync() == true) {
    return loadYaml(file.readAsStringSync()) as Map;
  }
  return null;
}

Future<Map> loadYamlFile(String path) async {
  final file = File(path);
  if (file.existsSync()) {
    return loadYaml(
      await file.readAsString(),
      sourceUrl: file.uri,
    ) as Map;
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
  final output = [];
  final maxColumnSizes = <int, int>{};
  for (final cells in list) {
    var i = 0;
    for (final cell in cells) {
      if (maxColumnSizes[i] == null ||
          maxColumnSizes[i] < AnsiStyles.strip(cell).length) {
        maxColumnSizes[i] = AnsiStyles.strip(cell).length;
      }
      i++;
    }
  }

  for (final cells in list) {
    var i = 0;
    final rowBuffer = StringBuffer();
    for (final cell in cells) {
      final colWidth = maxColumnSizes[i] + paddingSize;
      final cellWidth = AnsiStyles.strip(cell).length;
      var padding = colWidth - cellWidth;
      if (padding < paddingSize) padding = paddingSize;
      rowBuffer.write('$cell${List.filled(padding, ' ').join()}');
      i++;
    }
    output.add(rowBuffer.toString());
  }

  return output.join('\n');
}

/// Simple check to see if the [Directory] qualifies as a plugin repository.
bool isWorkspaceDirectory(Directory directory) {
  final melosYamlPath = melosYamlPathForDirectory(directory);
  return FileSystemEntity.isFileSync(melosYamlPath);
}

bool isPackageDirectory(Directory directory) {
  final pluginYamlPath = pubspecPathForDirectory(directory);
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
    if (_arg.trim() == '^') {
      return Platform.isWindows ? _arg : _arg.replaceAll('^', r'\');
    }

    // Inject Melos variables if any.
    environment.forEach((key, value) {
      _arg = _arg.replaceAll('\$$key', value);
      _arg = _arg.replaceAll(key, value);
    });

    return _arg;
  }).where((element) => element != null);

  final execProcess = await Process.start(
      executable, Platform.isWindows ? ['/C', '%MELOS_SCRIPT%'] : [],
      workingDirectory: workingDirectoryPath,
      includeParentEnvironment: true,
      environment: {
        ...environmentVariables,
        envKeyMelosTerminalWidth: terminalWidth.toString(),
        'MELOS_SCRIPT': filteredArgs.join(' '),
      },
      runInShell: true);

  if (!Platform.isWindows) {
    // Pipe in the arguments to trigger the script to run.
    execProcess.stdin.writeln(filteredArgs.join(' '));
    // Exit the process with the same exit code as the previous command.
    execProcess.stdin.writeln(r'exit $?');
  }

  var stdoutStream = execProcess.stdout;
  var stderrStream = execProcess.stderr;

  if (prefix != null && prefix.isNotEmpty) {
    final pluginPrefixTransformer =
        StreamTransformer<String, String>.fromHandlers(
            handleData: (String data, EventSink sink) {
      const lineSplitter = LineSplitter();
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

  final processStdout = <int>[];
  final processStderr = <int>[];
  final processStdoutCompleter = Completer<int>();
  final processStderrCompleter = Completer<int>();

  stdoutStream.listen((List<int> event) {
    processStdout.addAll(event);
    if (!onlyOutputOnError) {
      stdout.add(event);
    }
  }, onDone: processStdoutCompleter.complete);
  stderrStream.listen((List<int> event) {
    processStderr.addAll(event);
    if (!onlyOutputOnError) {
      stderr.add(event);
    }
  }, onDone: processStderrCompleter.complete);

  await processStdoutCompleter.future;
  await processStderrCompleter.future;
  final exitCode = await execProcess.exitCode;

  if (onlyOutputOnError && exitCode > 0) {
    stdout.add(processStdout);
    stderr.add(processStderr);
  }

  return exitCode;
}

bool isPubSubcommand() {
  try {
    return Process.runSync('pub', ['--version']).exitCode != 0;
  } on ProcessException {
    return true;
  }
}
