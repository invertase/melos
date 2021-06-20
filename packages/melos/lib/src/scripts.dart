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

import 'common/glob.dart';
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
  const Scripts(Map<String, Script> map) : super(map);

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
}

class Script {
  Script({
    required this.name,
    required this.run,
    required this.description,
    required this.env,
    required this.packageFilter,
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

    if (yaml is String) {
      run = yaml;
    } else if (yaml is Map<Object?, Object?>) {
      run = assertKeyIsA<String>(
        key: 'run',
        map: yaml,
        path: scriptPath,
      );
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
            ): assertIsA<String>(
              value: entry.value,
              key: entry.key,
              path: '$scriptPath/env',
            ),
      };

      final packageFilterMap = assertKeyIsA<Map<Object?, Object?>?>(
        key: 'select-package',
        map: yaml,
        path: scriptPath,
      );

      packageFilter = packageFilterMap == null
          ? null
          : packageFilterFromYaml(
              packageFilterMap,
              scriptName: name,
              workspacePath: workspacePath,
            );
    } else {
      throw MelosConfigException('Unsupported value for script $name');
    }

    return Script(
      name: name,
      run: run,
      description: description,
      env: env,
      packageFilter: packageFilter,
    );
  }

  /// Do not use
  @visibleForTesting
  static PackageFilter packageFilterFromYaml(
    Map<Object?, Object?> yaml, {
    required String scriptName,
    // necessary for the glob workaround
    required String workspacePath,
  }) {
    final packagePath = 'scripts/$scriptName/select-package';

    final scope = assertListOrString(
      key: filterOptionScope,
      map: yaml,
      path: packagePath,
    );
    final ignore = assertListOrString(
      key: filterOptionIgnore,
      map: yaml,
      path: packagePath,
    );
    final dirExists = assertListOrString(
      key: filterOptionDirExists,
      map: yaml,
      path: packagePath,
    );
    final fileExists = assertListOrString(
      key: filterOptionFileExists,
      map: yaml,
      path: packagePath,
    );
    final dependsOn = assertListOrString(
      key: filterOptionDependsOn,
      map: yaml,
      path: packagePath,
    );
    final noDependsOn = assertListOrString(
      key: filterOptionNoDependsOn,
      map: yaml,
      path: packagePath,
    );

    final updatedSince = assertIsA<String?>(
      value: yaml[filterOptionSince],
      key: filterOptionSince,
      path: packagePath,
    );

    final excludePrivatePackagesTmp = assertIsA<bool?>(
      value: yaml[filterOptionNoPrivate],
      key: filterOptionNoPrivate,
      path: packagePath,
    );
    final includePrivatePackagesTmp = assertIsA<bool?>(
      value: yaml[filterOptionPrivate],
      key: filterOptionNoPrivate,
      path: packagePath,
    );
    if (includePrivatePackagesTmp != null &&
        excludePrivatePackagesTmp != null) {
      throw MelosConfigException(
        'Cannot specify both --private and --no-private at the same time',
      );
    }
    bool? includePrivatePackages;
    if (includePrivatePackagesTmp != null) {
      includePrivatePackages = includePrivatePackagesTmp;
    }
    if (excludePrivatePackagesTmp != null) {
      includePrivatePackages = !excludePrivatePackagesTmp;
    }

    final published = assertIsA<bool?>(
      value: yaml[filterOptionPublished],
      key: filterOptionPublished,
      path: packagePath,
    );
    final nullSafe = assertIsA<bool?>(
      value: yaml[filterOptionNullsafety],
      key: filterOptionNullsafety,
      path: packagePath,
    );
    final flutter = assertIsA<bool?>(
      value: yaml[filterOptionFlutter],
      key: filterOptionFlutter,
      path: packagePath,
    );

    return PackageFilter(
      scope: scope
          .map((e) => createGlob(e, currentDirectoryPath: workspacePath))
          .toList(),
      ignore: ignore
          .map((e) => createGlob(e, currentDirectoryPath: workspacePath))
          .toList(),
      dirExists: dirExists,
      fileExists: fileExists,
      dependsOn: dependsOn,
      noDependsOn: noDependsOn,
      updatedSince: updatedSince,
      includePrivatePackages: includePrivatePackages,
      published: published,
      nullSafe: nullSafe,
      flutter: flutter,
    );
  }

  /// A unique identifier for the script
  final String name;

  /// The command to execute
  final String run;

  /// A short description, shown when using `melos run` with no argument.
  final String? description;

  /// Environment variables that will be passed to[run].
  final Map<String, String> env;

  /// If the [run] command is a melos command, allows filtering packages
  /// that will execute the command.
  final PackageFilter? packageFilter;

  @override
  bool operator ==(Object other) =>
      other is Script &&
      runtimeType == other.runtimeType &&
      other.name == name &&
      other.run == run &&
      other.description == description &&
      const DeepCollectionEquality().equals(other.env, env) &&
      other.packageFilter == packageFilter;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      name.hashCode ^
      run.hashCode ^
      description.hashCode ^
      const DeepCollectionEquality().hash(env) ^
      packageFilter.hashCode;

  @override
  String toString() {
    return '''
Script(
  name: $name,
  run: $run,
  description: $description,
  env: $env,
  packageFilter: ${packageFilter.toString().indent('  ')},
)''';
  }
}
