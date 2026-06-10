import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'common/utils.dart';
import 'common/validation.dart';
import 'package.dart';

// https://regex101.com/r/44dzaz/1
final _leadingMelosExecRegExp = RegExp(r'^\s*melos\s+exec');

const _scriptsExecDocsUrl =
    'https://melos.invertase.dev/configuration/scripts#exec';

/// Error message shown when a script specifies both `run` and `exec`, which is
/// no longer supported as of Melos 8.0.0.
String _execAndRunMigrationMessage({
  required String name,
  required Object run,
  required Object exec,
}) {
  final buffer = StringBuffer()
    ..writeln(
      'The script "$name" specifies both "run" and "exec", which is no longer '
      'supported as of Melos 8.0.0. A script either runs once in the workspace '
      'root with "run", or across multiple packages with "exec". They are now '
      'mutually exclusive.',
    );

  if (exec is Map) {
    // The old format used "run" for the command and "exec" for its options.
    // Show the user how to migrate to the new "exec.command" format.
    final runCommand = run is String ? run : '<command>';
    buffer
      ..writeln()
      ..writeln(
        'It looks like you were using "run" for the command and "exec" for '
        'its options. Move the command into "exec" under the new "command" '
        'key:',
      )
      ..writeln()
      ..writeln('    $name:')
      ..writeln('      exec:')
      ..writeln('        command: $runCommand');
    for (final entry in exec.entries) {
      buffer.writeln('        ${entry.key}: ${entry.value}');
    }
  } else {
    buffer
      ..writeln()
      ..writeln(
        'Both "run" and "exec" specify a command. Keep only one: use "run" to '
        'run the command once in the workspace root, or "exec" to run it '
        'across multiple packages.',
      );
  }

  buffer
    ..writeln()
    ..write('For more information, see $_scriptsExecDocsUrl.');

  return buffer.toString();
}

/// Error message shown when a script's `exec` is a configuration object that
/// does not specify the command to run via the `command` key.
String _execWithoutCommandMessage({required String name}) {
  return 'The script "$name" uses "exec" without a command. As of Melos '
      '8.0.0 the command must be specified with the "command" key inside '
      '"exec":\n'
      '\n'
      '    $name:\n'
      '      exec:\n'
      '        command: <command>\n'
      '        # ...other exec options such as concurrency\n'
      '\n'
      'For more information, see $_scriptsExecDocsUrl.';
}

class Scripts extends MapView<String, Script> {
  const Scripts(super.map);

  factory Scripts.fromYaml(
    Map<Object?, Object?> yaml, {
    required String workspacePath,
  }) {
    final scripts = yaml.map<String, Script>((key, value) {
      final name = assertIsA<String>(value: key, key: 'scripts');

      if (value == null) {
        throw MelosConfigException('The script $name has no value');
      }

      final script = Script.fromYaml(
        value,
        name: name,
        workspacePath: workspacePath,
      );

      return MapEntry(name, script);
    });

    return Scripts(UnmodifiableMapView(scripts));
  }

  static const Scripts empty = Scripts({});

  /// Validates the scripts. Throws a [MelosConfigException] if any script is
  /// invalid.
  void validate() {
    for (final script in values) {
      script.validate();
    }
  }

  Map<Object?, Object?> toJson() {
    return {
      for (final entry in entries) entry.key: entry.value.toJson(),
    };
  }
}

@immutable
class ExecOptions {
  const ExecOptions({
    this.concurrency,
    this.failFast,
    this.orderDependents,
  });

  final int? concurrency;
  final bool? failFast;
  final bool? orderDependents;

  Map<String, Object?> toJson() => {
    if (concurrency != null) 'concurrency': concurrency,
    if (failFast != null) 'failFast': failFast,
    if (orderDependents != null) 'orderDependents': orderDependents,
  };

  @override
  bool operator ==(Object other) =>
      other is ExecOptions &&
      runtimeType == other.runtimeType &&
      concurrency == other.concurrency &&
      failFast == other.failFast &&
      orderDependents == other.orderDependents;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      concurrency.hashCode ^
      failFast.hashCode ^
      orderDependents.hashCode;

  @override
  String toString() =>
      '''
ExecOptions(
  concurrency: $concurrency,
  failFast: $failFast,
  orderDependents: $orderDependents,
)''';
}

/// Controls how the standard streams of a script's child process are wired
/// to melos's own process.
enum ProcessStdio {
  /// Child stdout and stderr are piped through melos so it can prefix output
  /// with the script's indent. Child stdin is not connected. This is the
  /// default and is what every script gets without an explicit `stdio` key.
  pipe,

  /// Child stdin, stdout, and stderr are inherited from melos's own terminal,
  /// giving the script a real TTY. Required for any program that needs an
  /// attached terminal — `tmux attach`, `vim`, `less`, `flutter run` /
  /// `dart_frog dev` hot-reload keys. Melos drops its indented output prefix
  /// for the duration of the script in exchange for the TTY.
  inherit;

  /// Parses the value of a script's `stdio:` config key.
  ///
  /// Throws [MelosConfigException] if [value] is not a recognised mode.
  static ProcessStdio fromString(
    String value, {
    required String scriptName,
  }) {
    for (final mode in ProcessStdio.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    final allowed = ProcessStdio.values.map((m) => m.name).join(', ');
    throw MelosConfigException(
      'Invalid value "$value" for "stdio" on script $scriptName. '
      'Expected one of: $allowed.',
    );
  }
}

@immutable
class Script {
  const Script({
    required this.name,
    this.run,
    this.description,
    this.env = const {},
    this.packageFilters,
    this.exec,
    this.steps = const [],
    this.isPrivate = false,
    this.groups = const [],
    this.stdio = ProcessStdio.pipe,
  });

  factory Script.fromYaml(
    Object yaml, {
    required String name,
    required String workspacePath,
  }) {
    final scriptPath = 'scripts/$name';
    String? run;
    String? description;
    var env = <String, String>{};
    final List<String> steps;
    PackageFilters? packageFilters;
    ExecOptions? exec;
    bool? isPrivate;
    List<String>? groups;

    if (yaml is String) {
      run = yaml;
      steps = [];
      return Script(
        name: name,
        run: run,
        steps: steps,
        description: description,
        env: env,
        packageFilters: packageFilters,
        exec: exec,
        isPrivate: isPrivate ?? false,
        groups: groups,
      );
    }

    if (yaml is! Map<Object?, Object?>) {
      throw MelosConfigException('Unsupported value for script $name');
    }

    final execYaml = yaml['exec'];
    final runYaml = yaml['run'];

    // A script either runs once in the workspace root via "run", or across
    // multiple packages via "exec". The two are mutually exclusive.
    if (execYaml != null && runYaml != null) {
      throw MelosConfigException(
        _execAndRunMigrationMessage(name: name, run: runYaml, exec: execYaml),
      );
    }

    if (execYaml is String) {
      // Shorthand: the command to execute in each package, with the default
      // `melos exec` options.
      run = execYaml;
      exec = const ExecOptions();
    } else if (execYaml != null) {
      final execMap = assertKeyIsA<Map<Object?, Object?>>(
        key: 'exec',
        map: yaml,
        path: scriptPath,
      );

      final command = assertKeyIsA<String?>(
        key: 'command',
        map: execMap,
        path: '$scriptPath/exec',
      );
      if (command == null || command.isEmpty) {
        throw MelosConfigException(
          _execWithoutCommandMessage(name: name),
        );
      }

      run = command;
      exec = execOptionsFromYaml(execMap, scriptName: name);
    } else if (runYaml is String && runYaml.isNotEmpty) {
      run = assertKeyIsA<String>(
        key: 'run',
        map: yaml,
        path: scriptPath,
      );
    }

    final stepsList = yaml['steps'];
    steps = stepsList is List && stepsList.isNotEmpty
        ? assertListIsA<String>(
            key: 'steps',
            map: yaml,
            isRequired: false,
            assertItemIsA: (index, value) {
              return assertIsA<String>(
                value: value,
                index: index,
                path: scriptPath,
              );
            },
          )
        : [];

    description = assertKeyIsA<String?>(
      key: 'description',
      map: yaml,
      path: scriptPath,
    );
    final envMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'env',
      map: yaml,
      path: scriptPath,
    );

    env = <String, String>{
      if (envMap != null)
        for (final entry in envMap.entries)
          assertIsA<String>(
            value: entry.key,
            key: 'env',
            path: scriptPath,
          ): entry.value
              .toString(),
    };

    final packageFiltersMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'packageFilters',
      map: yaml,
      path: scriptPath,
    );

    packageFilters = packageFiltersMap == null
        ? null
        : PackageFilters.fromYaml(
            packageFiltersMap,
            path: 'scripts/$name/packageFilters',
            workspacePath: workspacePath,
          );

    isPrivate = assertKeyIsA<bool?>(
      key: 'private',
      map: yaml,
      path: scriptPath,
    );

    final groupsList = yaml['groups'];
    groups = groupsList is List && groupsList.isNotEmpty
        ? assertListIsA<String>(
            key: 'groups',
            map: yaml,
            isRequired: false,
            assertItemIsA: (index, value) {
              return assertIsA<String>(
                value: value,
                index: index,
                path: scriptPath,
              );
            },
          )
        : [];

    final stdioValue = assertKeyIsA<String?>(
      key: 'stdio',
      map: yaml,
      path: scriptPath,
    );
    final stdio = stdioValue != null
        ? ProcessStdio.fromString(stdioValue, scriptName: name)
        : ProcessStdio.pipe;

    return Script(
      name: name,
      run: run,
      steps: steps,
      description: description,
      env: env,
      packageFilters: packageFilters,
      exec: exec,
      isPrivate: isPrivate ?? false,
      groups: groups,
      stdio: stdio,
    );
  }

  @internal
  static Script? fromName(
    String name,
    Map<Object?, Object?> yaml,
    String workspacePath,
  ) {
    final script = yaml[name];
    if (script == null) {
      return null;
    }
    return Script.fromYaml(script, name: name, workspacePath: workspacePath);
  }

  @visibleForTesting
  static ExecOptions execOptionsFromYaml(
    Map<Object?, Object?> yaml, {
    required String scriptName,
  }) {
    final execPath = 'scripts/$scriptName/exec';

    final concurrency = assertKeyIsA<int?>(
      key: 'concurrency',
      map: yaml,
      path: execPath,
    );

    final failFast = assertKeyIsA<bool?>(
      key: 'failFast',
      map: yaml,
      path: execPath,
    );

    final orderDependents = assertKeyIsA<bool?>(
      key: 'orderDependents',
      map: yaml,
      path: execPath,
    );

    return ExecOptions(
      concurrency: concurrency,
      failFast: failFast,
      orderDependents: orderDependents,
    );
  }

  /// A unique identifier for the script.
  final String name;

  /// The command specified by the user.
  final String? run;

  /// A list of individual command steps to be executed as part of this script.
  /// Each string in the list represents a separate command to be run.
  /// These steps are executed in sequence. This is an alternative to
  /// specifying a single command in the [run] variable. If [steps] is
  /// provided, [run] should not be used.
  final List<String>? steps;

  /// A short description, shown when using `melos run` with no argument.
  final String? description;

  /// Environment variables that will be passed to [run].
  final Map<String, String> env;

  /// If the [run] command is a melos command, allows filtering packages that
  /// will execute the command.
  final PackageFilters? packageFilters;

  /// The options for `melos exec`, if [run] should be executed in multiple
  /// packages.
  final ExecOptions? exec;

  /// This option defines if the script shows up in the list of scripts or not
  final bool isPrivate;

  // The groups the script is belonging to
  final List<String>? groups;

  /// How the script's child process should connect its standard streams to
  /// melos. Defaults to [ProcessStdio.pipe]; set to [ProcessStdio.inherit] for
  /// interactive commands that need a real terminal.
  final ProcessStdio stdio;

  /// Returns the full command to run when executing this script.
  List<String> command([List<String>? extraArgs]) {
    String quoteScript(String script) => '"${script.replaceAll('"', r'\"')}"';

    final scriptCommand = run!.split(' ').toList();
    if (extraArgs != null && extraArgs.isNotEmpty) {
      scriptCommand.addAll(extraArgs);
    }

    final exec = this.exec;
    if (exec == null) {
      return scriptCommand;
    } else {
      final execCommand = ['melos', 'exec'];

      if (exec.concurrency != null) {
        execCommand.addAll(['--concurrency', '${exec.concurrency}']);
      }

      if (exec.failFast ?? false) {
        execCommand.add('--fail-fast');
      }

      if (exec.orderDependents ?? false) {
        execCommand.add('--order-dependents');
      }

      execCommand.addAll(['--', quoteScript(scriptCommand.join(' '))]);

      return execCommand;
    }
  }

  /// Validates the script. Throws a [MelosConfigException] if the script is
  /// invalid.
  void validate() {
    if (exec != null &&
        run != null &&
        run!.startsWith(_leadingMelosExecRegExp)) {
      throw MelosConfigException(
        'Do not use "melos exec" in the "command" of an "exec" script. The '
        'command is already being executed by "melos exec".\n'
        'For more information, see $_scriptsExecDocsUrl.\n'
        '\n'
        '    command: $run',
      );
    }
    if (stdio == ProcessStdio.inherit && exec != null) {
      throw MelosConfigException(
        'The script "$name" has both "stdio: inherit" and "exec", which are '
        'not compatible. "stdio: inherit" attaches a single child process to '
        'the parent terminal; "exec" runs the script across multiple '
        'packages.',
      );
    }
    if (stdio == ProcessStdio.inherit && (steps != null && steps!.isNotEmpty)) {
      throw MelosConfigException(
        'The script "$name" has both "stdio: inherit" and "steps", which are '
        'not compatible. "stdio: inherit" applies to a single process. Put '
        'the inherit flag on the individual scripts referenced from "steps" '
        'instead.',
      );
    }
  }

  Map<Object?, Object?> toJson() {
    final exec = this.exec;
    return {
      'name': name,
      if (exec == null) 'run': run,
      if (description != null) 'description': description,
      if (env.isNotEmpty) 'env': env,
      if (packageFilters != null) 'packageFilters': packageFilters!.toJson(),
      if (steps != null) 'steps': steps,
      if (exec != null)
        'exec': {
          if (run != null) 'command': run,
          ...exec.toJson(),
        },
      'private': isPrivate,
      if (groups != null) 'groups': groups,
      if (stdio != ProcessStdio.pipe) 'stdio': stdio.name,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is Script &&
      runtimeType == other.runtimeType &&
      other.name == name &&
      other.run == run &&
      other.description == description &&
      const DeepCollectionEquality().equals(other.env, env) &&
      other.packageFilters == packageFilters &&
      other.steps == steps &&
      other.isPrivate == isPrivate &&
      other.groups == groups &&
      other.exec == exec &&
      other.stdio == stdio;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      name.hashCode ^
      run.hashCode ^
      description.hashCode ^
      const DeepCollectionEquality().hash(env) ^
      packageFilters.hashCode ^
      steps.hashCode ^
      exec.hashCode ^
      isPrivate.hashCode ^
      groups.hashCode ^
      stdio.hashCode;

  @override
  String toString() {
    return '''
Script(
  name: $name,
  run: $run,
  description: $description,
  env: $env,
  packageFilters: ${packageFilters.toString().indent('  ')},
  steps: $steps,
  exec: ${exec.toString().indent('  ')},
  private: $isPrivate,
  groups: $groups,
  stdio: ${stdio.name}
)''';
  }
}
