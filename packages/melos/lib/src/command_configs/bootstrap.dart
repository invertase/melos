import 'package:collection/collection.dart';
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:pubspec/pubspec.dart';

import '../common/glob.dart';
import '../common/glob_equality.dart';
import '../common/utils.dart';
import '../common/validation.dart';
import '../lifecycle_hooks/lifecycle_hooks.dart';

/// Configurations for `melos bootstrap`.
@immutable
class BootstrapCommandConfigs {
  const BootstrapCommandConfigs({
    this.runPubGetInParallel = true,
    this.runPubGetOffline = false,
    this.enforceLockfile = false,
    this.environment,
    this.dependencies,
    this.devDependencies,
    this.dependencyOverridePaths = const [],
    this.hooks = LifecycleHooks.empty,
  });

  factory BootstrapCommandConfigs.fromYaml(
    Map<Object?, Object?> yaml, {
    required String workspacePath,
  }) {
    final runPubGetInParallel = assertKeyIsA<bool?>(
          key: 'runPubGetInParallel',
          map: yaml,
          path: 'command/bootstrap',
        ) ??
        true;

    final runPubGetOffline = assertKeyIsA<bool?>(
          key: 'runPubGetOffline',
          map: yaml,
          path: 'command/bootstrap',
        ) ??
        false;

    final enforceLockfile = assertKeyIsA<bool?>(
          key: 'enforceLockfile',
          map: yaml,
          path: 'command/bootstrap',
        ) ??
        false;

    final environment = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'environment',
      map: yaml,
    ).let(Environment.fromJson);

    final dependencies = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'dependencies',
      map: yaml,
    )?.map(
      (key, value) => MapEntry(
        key.toString(),
        DependencyReference.fromJson(value),
      ),
    );

    final devDependencies = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'dev_dependencies',
      map: yaml,
    )?.map(
      (key, value) => MapEntry(
        key.toString(),
        DependencyReference.fromJson(value),
      ),
    );

    final dependencyOverridePaths = assertListIsA<String>(
      key: 'dependencyOverridePaths',
      map: yaml,
      isRequired: false,
      assertItemIsA: (index, value) => assertIsA<String>(
        value: value,
        index: index,
        path: 'dependencyOverridePaths',
      ),
    );

    final hooksMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'hooks',
      map: yaml,
      path: 'command/bootstrap',
    );
    final hooks = hooksMap != null
        ? LifecycleHooks.fromYaml(hooksMap, workspacePath: workspacePath)
        : LifecycleHooks.empty;

    return BootstrapCommandConfigs(
      runPubGetInParallel: runPubGetInParallel,
      runPubGetOffline: runPubGetOffline,
      enforceLockfile: enforceLockfile,
      environment: environment,
      dependencies: dependencies,
      devDependencies: devDependencies,
      dependencyOverridePaths: dependencyOverridePaths
          .map(
            (override) =>
                createGlob(override, currentDirectoryPath: workspacePath),
          )
          .toList(),
      hooks: hooks,
    );
  }

  static const BootstrapCommandConfigs empty = BootstrapCommandConfigs();

  /// Whether to run `pub get` in parallel during bootstrapping.
  ///
  /// The default is `true`.
  final bool runPubGetInParallel;

  /// Whether to attempt to run `pub get` in offline mode during bootstrapping.
  /// Useful in closed network environments with pre-populated pubcaches.
  ///
  /// The default is `false`.
  final bool runPubGetOffline;

  /// Whether `pubspec.lock` is enforced when running `pub get` or not.
  /// Useful when you want to ensure the same versions of dependencies are used
  /// across different environments/machines.
  ///
  /// The default is `false`.
  final bool enforceLockfile;

  /// Environment configuration to be synced between all packages.
  final Environment? environment;

  /// Dependencies to be synced between all packages.
  final Map<String, DependencyReference>? dependencies;

  /// Dev dependencies to be synced between all packages.
  final Map<String, DependencyReference>? devDependencies;

  /// A list of [Glob]s for paths that contain packages to be used as dependency
  /// overrides for all packages managed in the Melos workspace.
  final List<Glob> dependencyOverridePaths;

  /// Lifecycle hooks for this command.
  final LifecycleHooks hooks;

  Map<String, Object?> toJson() {
    return {
      'runPubGetInParallel': runPubGetInParallel,
      'runPubGetOffline': runPubGetOffline,
      'enforceLockfile': enforceLockfile,
      if (environment != null) 'environment': environment!.toJson(),
      if (dependencies != null)
        'dependencies': dependencies!.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      if (devDependencies != null)
        'dev_dependencies': devDependencies!.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      if (dependencyOverridePaths.isNotEmpty)
        'dependencyOverridePaths':
            dependencyOverridePaths.map((path) => path.toString()).toList(),
      'hooks': hooks.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is BootstrapCommandConfigs &&
      runtimeType == other.runtimeType &&
      other.runPubGetInParallel == runPubGetInParallel &&
      other.runPubGetOffline == runPubGetOffline &&
      other.enforceLockfile == enforceLockfile &&
      // Extracting equality from environment here as it does not implement ==
      other.environment?.sdkConstraint == environment?.sdkConstraint &&
      const DeepCollectionEquality().equals(
        other.environment?.unParsedYaml,
        environment?.unParsedYaml,
      ) &&
      const DeepCollectionEquality().equals(other.dependencies, dependencies) &&
      const DeepCollectionEquality()
          .equals(other.devDependencies, devDependencies) &&
      const DeepCollectionEquality(GlobEquality())
          .equals(other.dependencyOverridePaths, dependencyOverridePaths) &&
      other.hooks == hooks;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      runPubGetInParallel.hashCode ^
      runPubGetOffline.hashCode ^
      enforceLockfile.hashCode ^
      // Extracting hashCode from environment here as it does not implement
      // hashCode
      (environment?.sdkConstraint).hashCode ^
      const DeepCollectionEquality().hash(
        environment?.unParsedYaml,
      ) ^
      const DeepCollectionEquality().hash(dependencies) ^
      const DeepCollectionEquality().hash(devDependencies) ^
      const DeepCollectionEquality(GlobEquality())
          .hash(dependencyOverridePaths) ^
      hooks.hashCode;

  @override
  String toString() {
    return '''
BootstrapCommandConfigs(
  runPubGetInParallel: $runPubGetInParallel,
  runPubGetOffline: $runPubGetOffline,
  enforceLockfile: $enforceLockfile,
  environment: $environment,
  dependencies: $dependencies,
  devDependencies: $devDependencies,
  dependencyOverridePaths: $dependencyOverridePaths,
  hooks: $hooks,
)''';
  }
}
