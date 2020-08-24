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

import 'package:path/path.dart' show relative, normalize, windows;
import 'package:yaml/yaml.dart';

import 'logger.dart';

String getMelosRoot() {
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
    exit(1);
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

String melosYamlPathForDirectory(Directory pluginDirectory) {
  return pluginDirectory.path + Platform.pathSeparator + 'melos.yaml';
}

String pubspecPathForDirectory(Directory pluginDirectory) {
  return pluginDirectory.path + Platform.pathSeparator + 'pubspec.yaml';
}

String relativePath(String path, String from) {
  if (Platform.isWindows) {
    return windows.normalize(path).replaceAll(r'\', r'\\');
  }
  return normalize(relative(path, from: from));
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
  final executable =
      Platform.isWindows ? r'%WINDIR%\system32\cmd.exe' : '/bin/sh';

  final execProcess = await Process.start(executable, [],
      workingDirectory: workingDirectoryPath,
      includeParentEnvironment: true,
      environment: environmentVariables,
      runInShell: Platform.isWindows);

  final filteredArgs = execArgs.map((arg) {
    var _arg = arg;

    // Remove empty args.
    if (_arg.trim().isEmpty) {
      return null;
    }

    // Swap line continuation characters to make them work cross platform.
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

  // Execute the command in the process.
  execProcess.stdin.writeln(filteredArgs.join(' '));

  // Exit with the exit code of the previous command.
  if (Platform.isWindows) {
    execProcess.stdin.writeln('EXIT /b %ERRORLEVEL%');
  } else {
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
