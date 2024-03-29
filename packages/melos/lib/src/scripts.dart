import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'common/utils.dart';
import 'common/validation.dart';
import 'package.dart';

// https://regex101.com/r/44dzaz/1
final _leadingMelosExecRegExp = RegExp(r'^\s*melos\s+exec');

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
  String toString() => '''
ExecOptions(
  concurrency: $concurrency,
  failFast: $failFast,
  orderDependents: $orderDependents,
)''';
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
      );
    }

    if (yaml is! Map<Object?, Object?>) {
      throw MelosConfigException('Unsupported value for script $name');
    }

    final execYaml = yaml['exec'];
    if (execYaml is String) {
      if (yaml['run'] is String) {
        throw MelosConfigException(
          'The script $name specifies a command in both "run" and "exec". '
          'Remove one of them.',
        );
      }
      run = execYaml;
      exec = const ExecOptions();
    } else {
      final execMap = assertKeyIsA<Map<Object?, Object?>?>(
        key: 'exec',
        map: yaml,
        path: scriptPath,
      );

      exec = execMap != null
          ? execOptionsFromYaml(execMap, scriptName: name)
          : null;
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

    final runYaml = yaml['run'];
    if (runYaml is String && runYaml.isNotEmpty) {
      run = execYaml is String
          ? execYaml
          : assertKeyIsA<String>(
              key: 'run',
              map: yaml,
              path: scriptPath,
            );
    }

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
          ): entry.value.toString(),
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

    return Script(
      name: name,
      run: run,
      steps: steps,
      description: description,
      env: env,
      packageFilters: packageFilters,
      exec: exec,
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
        'Do not use "melos exec" in "run" when also providing options in '
        '"exec". In this case the script in "run" is already being executed by '
        '"melos exec".\n'
        'For more information, see https://melos.invertase.dev/configuration/scripts#scriptsexec.\n'
        '\n'
        '    run: $run',
      );
    }
  }

  Map<Object?, Object?> toJson() {
    return {
      'name': name,
      'run': run,
      if (description != null) 'description': description,
      if (env.isNotEmpty) 'env': env,
      if (packageFilters != null) 'packageFilters': packageFilters!.toJson(),
      if (steps != null) 'steps': steps,
      if (exec != null) 'exec': exec!.toJson(),
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
      other.exec == exec;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      name.hashCode ^
      run.hashCode ^
      description.hashCode ^
      const DeepCollectionEquality().hash(env) ^
      packageFilters.hashCode ^
      steps.hashCode ^
      exec.hashCode;

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
)''';
  }
}
