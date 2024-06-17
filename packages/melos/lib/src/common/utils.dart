import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:args/args.dart';
import 'package:collection/collection.dart' hide stronglyConnectedComponents;
import 'package:graphs/graphs.dart';
import 'package:path/path.dart' as p;
import 'package:prompts/prompts.dart' as prompts;
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import '../logging.dart';
import '../package.dart';
import '../workspace.dart';
import 'environment_variable_key.dart';
import 'exception.dart';
import 'io.dart';
import 'platform.dart';

const globalOptionVerbose = 'verbose';
const globalOptionSdkPath = 'sdk-path';

const autoSdkPathOptionValue = 'auto';

const filterOptionScope = 'scope';
const filterOptionCategory = 'category';
const filterOptionIgnore = 'ignore';
const filterOptionDirExists = 'dir-exists';
const filterOptionFileExists = 'file-exists';
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

const publishOptionDryRun = 'dry-run';
const publishOptionNoDryRun = 'no-dry-run';
const publishOptionGitTagVersion = 'git-tag-version';
const publishOptionNoGitTagVersion = 'no-git-tag-version';
const publishOptionYes = 'yes';
const publishOptionForce = 'force';

extension Let<T> on T? {
  R? let<R>(R Function(T value) cb) {
    if (this == null) return null;

    return cb(this as T);
  }
}

/// Utility function to write inline multi-line strings with indentation and
/// without trailing a new line.
///
/// ```dart
/// print(multiLine([
///  'The quick brown fox jumps over the lazy dog.',
///  '', // Empty line
///  'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod.',
/// ]));
/// ```
String multiLine(List<String> lines) => lines.join('\n');

final melosPackageUri = Uri.parse('package:melos/melos.dart');

final _camelCasedDelimiterRegExp = RegExp(r'[_\s-]+');

extension StringUtils on String {
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

  String withoutTrailing(String trailer) {
    if (endsWith(trailer)) {
      return substring(0, length - trailer.length);
    }
    return this;
  }

  String get capitalized {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String get camelCased {
    if (isEmpty) return this;
    var isFirstWord = true;
    return splitMapJoin(
      _camelCasedDelimiterRegExp,
      onMatch: (m) => '',
      onNonMatch: (n) {
        if (isFirstWord) {
          isFirstWord = false;
          return n;
        }
        return n.capitalized;
      },
    );
  }
}

int get terminalWidth {
  if (currentPlatform.environment
      .containsKey(EnvironmentVariableKey.melosTerminalWidth)) {
    return int.tryParse(
          currentPlatform
              .environment[EnvironmentVariableKey.melosTerminalWidth]!,
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

String melosYamlPathForDirectory(String directory) =>
    p.join(directory, 'melos.yaml');

String melosStatePathForDirectory(String directory) =>
    p.join(directory, '.melos');

String melosOverridesYamlPathForDirectory(String directory) =>
    p.join(directory, 'melos_overrides.yaml');

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

extension YamlUtils on YamlNode {
  /// Converts a YAML node to a regular mutable Dart object.
  Object? toPlainObject() {
    final node = this;
    if (node is YamlScalar) {
      return node.value;
    }
    if (node is YamlMap) {
      return {
        for (final entry in node.nodes.entries)
          (entry.key as YamlNode).toPlainObject(): entry.value.toPlainObject(),
      };
    }
    if (node is YamlList) {
      return node.nodes.map((node) => node.toPlainObject()).toList();
    }
    throw FormatException(
      'Unsupported YAML node type encountered: ${node.runtimeType}',
      this,
    );
  }
}

/// Merges two maps together, overriding any values in [base] with those
/// with the same key in [overlay].
void mergeMap(Map<Object?, Object?> base, Map<Object?, Object?> overlay) {
  for (final entry in overlay.entries) {
    final overlayValue = entry.value;
    final baseValue = base[entry.key];
    if (overlayValue is Map<Object?, Object?>) {
      if (baseValue is Map<Object?, Object?>) {
        mergeMap(baseValue, overlayValue);
      } else {
        base[entry.key] = overlayValue;
      }
    } else if (overlayValue is List<Object?>) {
      if (baseValue is List<Object?>) {
        baseValue.addAll(overlayValue);
      } else {
        base[entry.key] = overlayValue;
      }
    } else {
      base[entry.key] = overlayValue;
    }
  }
}

/// Generate a link for display in a terminal.
///
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

Future<Process> startCommandRaw(
  List<String> command, {
  String? workingDirectory,
  Map<String, String> environment = const {},
  bool includeParentEnvironment = true,
}) {
  final executable = currentPlatform.isWindows ? 'cmd.exe' : '/bin/sh';
  workingDirectory ??= Directory.current.path;

  return Process.start(
    executable,
    currentPlatform.isWindows
        ? ['/C', '%${EnvironmentVariableKey.melosScript}%']
        : ['-c', 'eval "\$${EnvironmentVariableKey.melosScript}"'],
    workingDirectory: workingDirectory,
    environment: {
      ...environment,
      EnvironmentVariableKey.melosTerminalWidth: terminalWidth.toString(),
      EnvironmentVariableKey.melosScript: command.join(' '),
    },
    includeParentEnvironment: includeParentEnvironment,
  );
}

final _runningPids = <int>[];

List<int> get runningPids => UnmodifiableListView(_runningPids);

Future<int> startCommand(
  List<String> command, {
  String? prefix,
  Map<String, String> environment = const {},
  String? workingDirectory,
  bool onlyOutputOnError = false,
  bool includeParentEnvironment = true,
  required MelosLogger logger,
  String? group,
}) async {
  final processedCommand = command
      // Remove empty arguments.
      .whereNot((argument) => argument.trim().isEmpty)
      .map(_scriptArgumentFormatter(environment))
      .toList();

  final process = await startCommandRaw(
    processedCommand,
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
  );

  _runningPids.add(process.pid);

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
    (event) {
      processStdout.addAll(event);
      if (!onlyOutputOnError) {
        logger.logWithoutNewLine(
          utf8.decode(event, allowMalformed: true),
          group: group,
        );
      }
    },
    onDone: processStdoutCompleter.complete,
  );
  stderrStream.listen(
    (event) {
      processStderr.addAll(event);
      if (!onlyOutputOnError) {
        logger.error(utf8.decode(event, allowMalformed: true), group: group);
      }
    },
    onDone: processStderrCompleter.complete,
  );

  await processStdoutCompleter.future;
  await processStderrCompleter.future;
  final exitCode = await process.exitCode;

  _runningPids.remove(process.pid);

  if (onlyOutputOnError && exitCode > 0) {
    logger.log(
      utf8.decode(processStdout, allowMalformed: true),
      group: group,
    );
    logger.error(
      utf8.decode(processStderr, allowMalformed: true),
      group: group,
    );
  }

  return exitCode;
}

String Function(String) _scriptArgumentFormatter(
  Map<String, String> environment,
) {
  return (argument) {
    // Attempt to make line continuations Windows & Linux compatible.
    if (argument.trim() == r'\') {
      return currentPlatform.isWindows
          ? argument.replaceAll(r'\', '^')
          : argument;
    }
    if (argument.trim() == '^') {
      return currentPlatform.isWindows
          ? argument
          : argument.replaceAll('^', r'\');
    }

    // Inject MELOS_* variables if any.
    environment.forEach((key, value) {
      if (key.startsWith('MELOS_')) {
        argument = argument.replaceAll('\$$key', value);
        argument = argument.replaceAll(key, value);
      }
    });

    return argument;
  };
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

/// Sorts [packages] in topological order so they can be published without
/// errors.
///
/// Packages with inter-dependencies cannot be topologically sorted and will
/// be sorted by name length. This is a heuristic to better handle cyclic
/// dependencies in federated plugins.
void sortPackagesForPublishing(List<Package> packages) {
  final packageNames = packages.map((package) => package.name).toList();
  final graph = <String, Iterable<String>>{
    for (final package in packages)
      package.name: [
        ...package.dependencies.where(packageNames.contains),
        ...package.devDependencies.where(packageNames.contains),
      ],
  };
  final ordered =
      stronglyConnectedComponents(graph.keys, (package) => graph[package]!)
          .expand(
            (component) => component.sortedByCompare(
              (package) => package.length,
              (a, b) => b - a,
            ),
          )
          .toList();

  packages.sort((a, b) {
    return ordered.indexOf(a.name).compareTo(ordered.indexOf(b.name));
  });
}

/// Returns a list of dependency cycles between [packages], taking into
/// account only workspace dependencies.
///
/// All dependencies between packages in the workspace are considered, including
/// `dev_dependencies` and `dependency_overrides`.
List<List<Package>> findCyclicDependenciesInWorkspace(List<Package> packages) {
  return stronglyConnectedComponents(
    packages,
    (package) => package.allDependenciesInWorkspace.values,
  ).where((component) => component.length > 1).map((component) {
    try {
      topologicalSort(
        component,
        (package) => package.allDependenciesInWorkspace.values,
      );
    } on CycleException<Package> catch (error) {
      return error.cycle;
    }
    throw StateError('Expected a cycle to be found.');
  }).toList();
}

/// Given a workspace and package, this assembles the correct command to run pub
/// / dart pub / flutter pub.
///
/// Takes into account a potential sdk path being provided. If no sdk path is
/// provided then it will assume to use the pub command available in
/// [EnvironmentVariableKey.path].
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

extension OptionalArgResults on ArgResults {
  Object? optional(String name) => wasParsed(name) ? this[name] : null;
}

String removeTrailingSlash(String url) {
  return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
