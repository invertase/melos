/*
 * Copyright (c) 2020-present Invertase Limited & Contributors
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

import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'common/utils.dart';
import 'common/validation.dart';
import 'package.dart';

/// Scripts to be executed before/after a melos command.
class LifecycleHook {
  LifecycleHook._({required this.pre, required this.post});

  /// A script to execute before the melos command starts.
  final Script? pre;

  /// A script to execute before the melos command completed.
  final Script? post;
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

  LifecycleHook get bootstrap => _lifecycleHookFor('bootstrap');
  LifecycleHook get version => _lifecycleHookFor('version');
  LifecycleHook get clean => _lifecycleHookFor('clean');

  Set<Script> lifecycles() {
    return {
      for (final lifecycle in [bootstrap, version, clean]) ...[
        if (lifecycle.pre != null) lifecycle.pre!,
        if (lifecycle.post != null) lifecycle.post!,
      ],
    };
  }

  LifecycleHook _lifecycleHookFor(String name) {
    return LifecycleHook._(
      pre: this[name],
      post: this['post$name'],
    );
  }

  Map<Object?, Object?> toJson() {
    return {
      for (final entry in entries) entry.key: entry.value.toJson(),
    };
  }
}

@immutable
class ExecOptions {
  ExecOptions({
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
  Script({
    required this.name,
    required this.run,
    this.description,
    this.env = const {},
    this.filter,
    this.exec,
  });

  factory Script.fromYaml(
    Object yaml, {
    required String name,
    required String workspacePath,
  }) {
    final scriptPath = 'scripts/$name';
    String run;
    String? description;
    var env = <String, String>{};
    PackageFilter? packageFilter;
    ExecOptions? exec;

    if (yaml is String) {
      run = yaml;
    } else if (yaml is Map<Object?, Object?>) {
      final execYaml = yaml['exec'];
      if (execYaml is String) {
        if (yaml['run'] is String) {
          throw MelosConfigException(
            'The script $name specifies a command in both "run" and "exec". '
            'Remove one of them.',
          );
        }
        run = execYaml;
      } else {
        run = assertKeyIsA<String>(
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

      final packageFilterMap = assertKeyIsA<Map<Object?, Object?>?>(
        key: 'select-package',
        map: yaml,
        path: scriptPath,
      );

      packageFilter = packageFilterMap == null
          ? null
          : PackageFilter.fromYaml(
              packageFilterMap,
              path: 'scripts/$name/select-package',
              workspacePath: workspacePath,
            );

      if (execYaml is String) {
        exec = ExecOptions();
      } else {
        final execMap = assertKeyIsA<Map<Object?, Object?>?>(
          key: 'exec',
          map: yaml,
          path: scriptPath,
        );

        exec = execMap == null
            ? null
            : execOptionsFromYaml(execMap, scriptName: name);
      }
    } else {
      throw MelosConfigException('Unsupported value for script $name');
    }

    return Script(
      name: name,
      run: run,
      description: description,
      env: env,
      filter: packageFilter,
      exec: exec,
    );
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
  final String run;

  /// The command to run when executing this script.
  late final effectiveRun = _buildEffectiveCommand();

  /// A short description, shown when using `melos run` with no argument.
  final String? description;

  /// Environment variables that will be passed to [run].
  final Map<String, String> env;

  /// If the [run] command is a melos command, allows filtering packages that
  /// will execute the command.
  final PackageFilter? filter;

  /// The options for `melos exec`, if [run] should be executed in multiple
  /// packages.
  final ExecOptions? exec;

  String _buildEffectiveCommand() {
    String quoteScript(String script) => '"${script.replaceAll('"', r'\"')}"';

    final exec = this.exec;
    if (exec != null) {
      final parts = ['melos', 'exec'];

      if (exec.concurrency != null) {
        parts.addAll(['--concurrency', '${exec.concurrency}']);
      }

      if (exec.failFast ?? false) {
        parts.add('--fail-fast');
      }

      if (exec.orderDependents ?? false) {
        parts.add('--order-dependents');
      }

      parts.addAll(['--', quoteScript(run)]);

      return parts.join(' ');
    }
    return run;
  }

  Map<Object?, Object?> toJson() {
    return {
      'name': name,
      'run': run,
      if (description != null) 'description': description,
      if (env.isNotEmpty) 'env': env,
      if (filter != null) 'select-package': filter!.toJson(),
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
      other.filter == filter &&
      other.exec == exec;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      name.hashCode ^
      run.hashCode ^
      description.hashCode ^
      const DeepCollectionEquality().hash(env) ^
      filter.hashCode ^
      exec.hashCode;

  @override
  String toString() {
    return '''
Script(
  name: $name,
  run: $run,
  description: $description,
  env: $env,
  packageFilter: ${filter.toString().indent('  ')},
  exec: ${exec.toString().indent('  ')},
)''';
  }
}
