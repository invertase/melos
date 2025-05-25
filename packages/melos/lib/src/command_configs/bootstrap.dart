import 'package:collection/collection.dart';
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

import '../common/extensions/dependency.dart';
import '../common/extensions/environment.dart';
import '../common/glob.dart';
import '../common/glob_equality.dart';
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
    final runPubGetInParallel =
        assertKeyIsA<bool?>(
          key: 'runPubGetInParallel',
          map: yaml,
          path: 'command/bootstrap',
        ) ??
        true;

    final runPubGetOffline =
        assertKeyIsA<bool?>(
          key: 'runPubGetOffline',
          map: yaml,
          path: 'command/bootstrap',
        ) ??
        false;

    final enforceLockfile =
        assertKeyIsA<bool?>(
          key: 'enforceLockfile',
          map: yaml,
          path: 'command/bootstrap',
        ) ??
        false;

    // Create a dummy pubspec name to be able to extract the constraints using
    // the pubspec parser.
    final bootstrapConstraints = Pubspec.fromJson(
      {'name': 'bootstrap', ...yaml},
      lenient: true,
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

    final environment = bootstrapConstraints.environment;
    final dependencies = bootstrapConstraints.dependencies;
    final devDependencies = bootstrapConstraints.devDependencies;

    return BootstrapCommandConfigs(
      runPubGetInParallel: runPubGetInParallel,
      runPubGetOffline: runPubGetOffline,
      enforceLockfile: enforceLockfile,
      environment: environment.isEmpty ? null : environment,
      dependencies: dependencies.isEmpty ? null : dependencies,
      devDependencies: devDependencies.isEmpty ? null : devDependencies,
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
  final Map<String, Dependency>? dependencies;

  /// Dev dependencies to be synced between all packages.
  final Map<String, Dependency>? devDependencies;

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
      if (dependencies != null) 'dependencies': dependencies!.toJson(),
      if (devDependencies != null)
        'dev_dependencies': devDependencies!.toJson(),
      if (dependencyOverridePaths.isNotEmpty)
        'dependencyOverridePaths': dependencyOverridePaths
            .map((path) => path.toString())
            .toList(),
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
      other.environment.sdkConstraint == environment.sdkConstraint &&
      const DeepCollectionEquality().equals(other.environment, environment) &&
      const DeepCollectionEquality().equals(other.dependencies, dependencies) &&
      const DeepCollectionEquality().equals(
        other.devDependencies,
        devDependencies,
      ) &&
      const DeepCollectionEquality(
        GlobEquality(),
      ).equals(other.dependencyOverridePaths, dependencyOverridePaths) &&
      other.hooks == hooks;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      runPubGetInParallel.hashCode ^
      runPubGetOffline.hashCode ^
      enforceLockfile.hashCode ^
      // Extracting hashCode from environment here as it does not implement
      // hashCode
      environment.sdkConstraint.hashCode ^
      const DeepCollectionEquality().hash(environment) ^
      const DeepCollectionEquality().hash(dependencies) ^
      const DeepCollectionEquality().hash(devDependencies) ^
      const DeepCollectionEquality(
        GlobEquality(),
      ).hash(dependencyOverridePaths) ^
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
