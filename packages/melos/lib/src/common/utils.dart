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
import 'dart:isolate';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:graphs/graphs.dart';
import 'package:path/path.dart' as p;
import 'package:prompts/prompts.dart' as prompts;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import '../logging.dart';
import '../package.dart';
import '../workspace.dart';
import 'exception.dart';
import 'io.dart';
import 'platform.dart';

const globalOptionVerbose = 'verbose';
const globalOptionSdkPath = 'sdk-path';

const autoSdkPathOptionValue = 'auto';

const filterOptionScope = 'scope';
const filterOptionIgnore = 'ignore';
const filterOptionDirExists = 'dir-exists';
const filterOptionFileExists = 'file-exists';
const filterOptionSince = 'since';
const filterOptionDiff = 'diff';
const filterOptionNullsafety = 'nullsafety';
const filterOptionNoPrivate = 'no-private';
const filterOptionPrivate = 'private';
const filterOptionPublished = 'published';
const filterOptionFlutter = 'flutter';
const filterOptionDependsOn = 'depends-on';
const filterOptionNoDependsOn = 'no-depends-on';
const filterOptionIncludeDependents = 'include-dependents';
const filterOptionIncludeDependencies = 'include-dependencies';

extension Let<T> on T? {
  R? let<R>(R Function(T value) cb) {
    if (this == null) return null;

    return cb(this as T);
  }
}

String describeEnum(Object value) => value.toString().split('.').last;

// MELOS_PACKAGES environment variable is a comma delimited list of
// package names - used instead of filters if it is present.
// This can be user defined or can come from package selection in `melos run`.
const envKeyMelosPackages = 'MELOS_PACKAGES';

const envKeyMelosSdkPath = 'MELOS_SDK_PATH';

const envKeyMelosTerminalWidth = 'MELOS_TERMINAL_WIDTH';

final melosPackageUri = Uri.parse('package:melos/melos.dart');

extension Indent on String {
  String indent(String indent) {
    final split = this.split('\n');

    final buffer = StringBuffer();

    buffer.writeln(split.first);

    for (var i = 1; i < split.length; i++) {
      buffer.write(indent);
      if (i + 1 == split.length) {
        // last line
        buffer.write(split[i]);
      } else {
        buffer.writeln(split[i]);
      }
    }

    return buffer.toString();
  }
}

int get terminalWidth {
  if (currentPlatform.environment.containsKey(envKeyMelosTerminalWidth)) {
    return int.tryParse(
          currentPlatform.environment[envKeyMelosTerminalWidth]!,
          radix: 10,
        ) ??
        80;
  }

  if (stdout.hasTerminal) {
    return stdout.terminalColumns;
  }

  return 80;
}

// https://regex101.com/r/XlfVPy/1
final _dartSdkVersionRegexp = RegExp(r'^Dart SDK version: (\S+)');

Version currentDartVersion(String dartTool) {
  final result = Process.runSync(
    dartTool,
    ['--version'],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
    runInShell: true,
  );

  if (result.exitCode != 0) {
    throw Exception(
      'Failed to get current Dart version:\n${result.stdout}\n${result.stderr}',
    );
  }

  // Older Dart SDK versions output to stderr instead of stdout.
  final stdout = result.stdout as String;
  final stderr = result.stderr as String;
  final versionOutput = stdout.trim().isEmpty ? stderr : stdout;

  final versionString =
      _dartSdkVersionRegexp.matchAsPrefix(versionOutput)?.group(1);
  if (versionString == null) {
    throw Exception('Unable to parse Dart version from:\n$versionOutput');
  }

  return Version.parse(versionString);
}

String nextDartMajorVersion([String dartTool = 'dart']) {
  return currentDartVersion(dartTool).nextMajor.toString();
}

bool isPubspecOverridesSupported([String dartTool = 'dart']) =>
    currentDartVersion(dartTool).compareTo(Version.parse('2.17.0-266.0.dev')) >=
    0;

bool canRunPubGetConcurrently([String dartTool = 'dart']) =>
    currentDartVersion(dartTool).compareTo(Version.parse('2.16.0')) >= 0;

T _promptWithTerminal<T>(
  T Function() runPrompt, {
  required String message,
  T? defaultsTo,
  T? defaultsToWithoutPrompt,
  bool requirePrompt = false,
}) {
  if (stdin.hasTerminal) {
    return runPrompt();
  }

  if (!requirePrompt) {
    if (defaultsToWithoutPrompt is T) {
      return defaultsToWithoutPrompt;
    }

    if (defaultsTo is T) {
      return defaultsTo;
    }
  }

  throw PromptException(message);
}

class PromptException extends MelosException {
  PromptException(this.message);

  final String message;

  @override
  String toString() => 'Was unable to prompt for input:\n$message';
}

String promptInput(
  String message, {
  String? defaultsTo,
  String? defaultsToWithoutPrompt,
  bool requirePrompt = false,
}) {
  return _promptWithTerminal(
    () => prompts.get(message, defaultsTo: defaultsTo),
    message: message,
    defaultsTo: defaultsTo,
    defaultsToWithoutPrompt: defaultsToWithoutPrompt,
    requirePrompt: requirePrompt,
  );
}

bool promptBool({
  String message = 'Continue?',
  bool defaultsTo = false,
  bool? defaultsToWithoutPrompt,
  bool requirePrompt = false,
}) {
  return _promptWithTerminal(
    () => prompts.getBool(message, defaultsTo: defaultsTo),
    message: message,
    defaultsTo: defaultsTo,
    defaultsToWithoutPrompt: defaultsToWithoutPrompt,
    requirePrompt: requirePrompt,
  );
}

T promptChoice<T>(
  String message,
  Iterable<T> options, {
  T? defaultsTo,
  T? defaultsToWithoutPrompt,
  String prompt = 'Enter your choice',
  bool interactive = true,
  bool requirePrompt = false,
}) {
  return _promptWithTerminal(
    () => prompts.choose(
      message,
      options,
      defaultsTo: defaultsTo,
      prompt: prompt,
      interactive: interactive,
    )!,
    message: message,
    defaultsTo: defaultsTo,
    defaultsToWithoutPrompt: defaultsToWithoutPrompt,
    requirePrompt: requirePrompt,
  );
}

bool get isCI {
  final keys = currentPlatform.environment.keys;
  return keys.contains('CI') ||
      keys.contains('CONTINUOUS_INTEGRATION') ||
      keys.contains('BUILD_NUMBER') ||
      keys.contains('RUN_ID');
}

String printablePath(String path) {
  return p.posix
      .prettyUri(p.posix.normalize(path))
      .replaceAll(RegExp(r'[/\\]+'), '/');
}

String get pathEnvVarSeparator => currentPlatform.isWindows ? ';' : ':';

String addToPathEnvVar({
  required String directory,
  required String currentPath,
  bool prepend = false,
}) {
  if (prepend) {
    return '$directory$pathEnvVarSeparator$currentPath';
  } else {
    return '$currentPath$pathEnvVarSeparator$directory';
  }
}

Future<String> getMelosRoot() async {
  final melosPackageFileUri = await Isolate.resolvePackageUri(melosPackageUri);

  // Get from lib/melos.dart to the package root
  return p.normalize('${melosPackageFileUri!.toFilePath()}/../..');
}

YamlMap? loadYamlFileSync(String path) {
  if (!fileExists(path)) return null;

  return loadYaml(readTextFile(path)) as YamlMap;
}

Future<YamlMap?> loadYamlFile(String path) async {
  if (!fileExists(path)) return null;

  return loadYaml(
    await readTextFileAsync(path),
    sourceUrl: Uri.parse(path),
  ) as YamlMap;
}

String melosYamlPathForDirectory(String directory) =>
    p.join(directory, 'melos.yaml');

String melosStatePathForDirectory(String directory) =>
    p.join(directory, '.melos');

String pubspecPathForDirectory(String directory) =>
    p.join(directory, 'pubspec.yaml');

String pubspecOverridesPathForDirectory(String directory) =>
    p.join(directory, 'pubspec_overrides.yaml');

String relativePath(String path, String from) {
  if (currentPlatform.isWindows) {
    return p.windows
        .normalize(p.relative(path, from: from))
        .replaceAll(r'\', r'\\');
  }
  return p.normalize(p.relative(path, from: from));
}

String listAsPaddedTable(List<List<String>> table, {int paddingSize = 1}) {
  final output = <String>[];
  final maxColumnSizes = <int, int>{};
  for (final row in table) {
    var i = 0;
    for (final column in row) {
      if (maxColumnSizes[i] == null ||
          maxColumnSizes[i]! < AnsiStyles.strip(column).length) {
        maxColumnSizes[i] = AnsiStyles.strip(column).length;
      }
      i++;
    }
  }

  for (final row in table) {
    var i = 0;
    final rowBuffer = StringBuffer();
    for (final column in row) {
      final colWidth = maxColumnSizes[i]! + paddingSize;
      final cellWidth = AnsiStyles.strip(column).length;
      var padding = colWidth - cellWidth;
      if (padding < paddingSize) padding = paddingSize;

      // last cell of the list, no need for padding
      if (i + 1 >= row.length) padding = 0;

      rowBuffer.write('$column${List.filled(padding, ' ').join()}');
      i++;
    }
    output.add(rowBuffer.toString());
  }

  return output.join('\n');
}

/// Generate a link for display in a terminal.
/// Similar to `<a href="$url">$text</a>` in HTML.
/// If ANSI escape codes are not supported, the link will be displayed as plain
/// text.
String link(Uri url, String text) {
  if (ansiStylesDisabled) {
    return '$text $url';
  } else {
    return '\x1B]8;;$url\x07$text\x1B]8;;\x07';
  }
}

/// Simple check to see if the [Directory] qualifies as a plugin repository.
bool isWorkspaceDirectory(String directory) =>
    fileExists(melosYamlPathForDirectory(directory));

bool isPackageDirectory(String directory) =>
    fileExists(pubspecPathForDirectory(directory));

Future<Process> startCommandRaw(
  String command, {
  String? workingDirectory,
  Map<String, String> environment = const {},
  bool includeParentEnvironment = true,
}) {
  final executable = currentPlatform.isWindows ? 'cmd.exe' : '/bin/sh';
  workingDirectory ??= Directory.current.path;

  return Process.start(
    executable,
    currentPlatform.isWindows
        ? ['/C', '%MELOS_SCRIPT%']
        : ['-c', r'eval "$MELOS_SCRIPT"'],
    workingDirectory: workingDirectory,
    environment: {
      ...environment,
      envKeyMelosTerminalWidth: terminalWidth.toString(),
      'MELOS_SCRIPT': command,
    },
    includeParentEnvironment: includeParentEnvironment,
  );
}

Future<int> startCommand(
  List<String> command, {
  String? prefix,
  Map<String, String> environment = const {},
  String? workingDirectory,
  bool onlyOutputOnError = false,
  bool includeParentEnvironment = true,
  required MelosLogger logger,
}) async {
  final processedCommand = command
      .map((arg) {
        // Remove empty args.
        if (arg.trim().isEmpty) {
          return null;
        }

        // Attempt to make line continuations Windows & Linux compatible.
        if (arg.trim() == r'\') {
          return currentPlatform.isWindows ? arg.replaceAll(r'\', '^') : arg;
        }
        if (arg.trim() == '^') {
          return currentPlatform.isWindows ? arg : arg.replaceAll('^', r'\');
        }

        // Inject MELOS_* variables if any.
        environment.forEach((key, value) {
          if (key.startsWith('MELOS_')) {
            arg = arg.replaceAll('\$$key', value);
            arg = arg.replaceAll(key, value);
          }
        });

        return arg;
      })
      .where((element) => element != null)
      .join(' ');

  final process = await startCommandRaw(
    processedCommand,
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
  );

  var stdoutStream = process.stdout;
  var stderrStream = process.stderr;

  if (prefix != null && prefix.isNotEmpty) {
    final pluginPrefixTransformer =
        StreamTransformer<String, String>.fromHandlers(
      handleData: (data, sink) {
        const lineSplitter = LineSplitter();
        var lines = lineSplitter.convert(data);
        lines = lines
            .map((line) => '$prefix$line${line.contains('\n') ? '' : '\n'}')
            .toList();
        sink.add(lines.join());
      },
    );

    stdoutStream = process.stdout
        .transform<String>(utf8.decoder)
        .transform<String>(pluginPrefixTransformer)
        .transform<List<int>>(utf8.encoder);

    stderrStream = process.stderr
        .transform<String>(utf8.decoder)
        .transform<String>(pluginPrefixTransformer)
        .transform<List<int>>(utf8.encoder);
  }

  final processStdout = <int>[];
  final processStderr = <int>[];
  final processStdoutCompleter = Completer<void>();
  final processStderrCompleter = Completer<void>();

  stdoutStream.listen(
    (List<int> event) {
      processStdout.addAll(event);
      if (!onlyOutputOnError) {
        logger.write(utf8.decode(event, allowMalformed: true));
      }
    },
    onDone: processStdoutCompleter.complete,
  );
  stderrStream.listen(
    (List<int> event) {
      processStderr.addAll(event);
      if (!onlyOutputOnError) {
        logger.stderr(utf8.decode(event, allowMalformed: true));
      }
    },
    onDone: processStderrCompleter.complete,
  );

  await processStdoutCompleter.future;
  await processStderrCompleter.future;
  final exitCode = await process.exitCode;

  if (onlyOutputOnError && exitCode > 0) {
    logger.stdout(utf8.decode(processStdout, allowMalformed: true));
    logger.stderr(utf8.decode(processStderr, allowMalformed: true));
  }

  return exitCode;
}

bool isPubSubcommand({required MelosWorkspace workspace}) {
  try {
    return Process.runSync(
          workspace.sdkTool('pub'),
          ['--version'],
          runInShell: true,
        ).exitCode !=
        0;
  } on ProcessException {
    return true;
  }
}

/// Sorts packages in topological order so they may be published in the order
/// they're sorted.
///
/// Packages with inter-dependencies cannot be topologically sorted and will
/// remain unchanged.
void sortPackagesTopologically(List<Package> packages) {
  final packageNames = packages.map((el) => el.name).toList();
  final graph = <String, Iterable<String>>{
    for (var package in packages)
      package.name: package.dependencies.where(packageNames.contains),
  };
  try {
    final ordered = topologicalSort(graph.keys, (key) => graph[key]!);
    packages.sort((a, b) {
      // `ordered` is in reverse ordering to our desired publish precedence.
      return ordered.indexOf(b.name).compareTo(ordered.indexOf(a.name));
    });
  } on CycleException<String> {
    // Cannot sort packages with inter-dependencies. Leave as-is.
  }
}

/// Given a workspace and package, this assembles the correct command to run pub
/// / dart pub / flutter pub.
///
/// Takes into account a potential sdk path being provided. If no sdk path is
/// provided then it will assume to use the pub command available in PATH.
List<String> pubCommandExecArgs({
  required bool useFlutter,
  required MelosWorkspace workspace,
}) {
  return [
    if (useFlutter)
      workspace.sdkTool('flutter')
    else if (isPubSubcommand(workspace: workspace))
      workspace.sdkTool('dart'),
    'pub',
  ];
}

extension StreamUtils<T> on Stream<T> {
  /// Runs [convert] for each event in this stream and emits the result, while
  /// ensuring that no more events than specified by [parallelism] are being
  /// processed at any given time.
  ///
  /// If [parallelism] is `null`, [Platform.numberOfProcessors] is used.
  Stream<R> parallel<R>(
    Future<R> Function(T) convert, {
    int? parallelism,
  }) async* {
    final pending = <Future<R>>[];
    final done = <Future<R>>[];

    await for (final value in this) {
      late final Future<R> future;
      future = Future(() async {
        try {
          return await convert(value);
        } finally {
          pending.remove(future);
          done.add(future);
        }
      });
      pending.add(future);

      if (pending.length < (parallelism ?? Platform.numberOfProcessors)) {
        continue;
      }

      await Future.any(pending);

      for (final future in done) {
        yield await future;
      }
      done.clear();
    }

    for (final result in await Future.wait(pending)) {
      yield result;
    }
  }
}

extension Utf8StreamUtils on Stream<List<int>> {
  /// Fully consumes this stream and returns the decoded string, while also
  /// starting to call [log] after [timeout] has elapsed for the previously
  /// decoded lines and all subsequent lines.
  Future<String> toStringAndLogAfterTimeout({
    required Duration timeout,
    required void Function(String) log,
  }) async {
    final bufferedLines = <String>[];
    final stopwatch = Stopwatch()..start();
    return transform(utf8.decoder).transform(const LineSplitter()).map((line) {
      if (stopwatch.elapsed >= timeout) {
        if (bufferedLines.isNotEmpty) {
          bufferedLines.forEach(log);
          bufferedLines.clear();
        }
        log(line);
      } else {
        bufferedLines.add(line);
      }

      return line;
    }).join('\n');
  }
}

// Encodes a [value] as a JSON string with indentation.
String prettyEncodeJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);
