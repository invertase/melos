import 'package:meta/meta.dart';

import '../common/validation.dart';
import '../lifecycle_hooks/lifecycle_hooks.dart';

/// Configurations for `melos clean`.
@immutable
class CleanCommandConfigs {
  const CleanCommandConfigs({
    this.hooks = LifecycleHooks.empty,
  });

  factory CleanCommandConfigs.fromYaml(
    Map<Object?, Object?> yaml, {
    required String workspacePath,
  }) {
    final hooksMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'hooks',
      map: yaml,
      path: 'command/clean',
    );
    final hooks = hooksMap != null
        ? LifecycleHooks.fromYaml(hooksMap, workspacePath: workspacePath)
        : LifecycleHooks.empty;

    return CleanCommandConfigs(
      hooks: hooks,
    );
  }

  static const CleanCommandConfigs empty = CleanCommandConfigs();

  final LifecycleHooks hooks;

  Map<String, Object?> toJson() {
    return {
      'hooks': hooks.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is CleanCommandConfigs &&
      runtimeType == other.runtimeType &&
      other.hooks == hooks;

  @override
  int get hashCode => runtimeType.hashCode ^ hooks.hashCode;

  @override
  String toString() {
    return '''
CleanCommandConfigs(
  hooks: $hooks,
)''';
  }
}
