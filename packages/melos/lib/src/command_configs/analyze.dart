import 'package:meta/meta.dart';

import '../common/validation.dart';
import '../lifecycle_hooks/lifecycle_hooks.dart';

/// Configurations for `melos format`.
@immutable
class AnalyzeCommandConfigs {
  const AnalyzeCommandConfigs({
    this.hooks = LifecycleHooks.empty,
  });

  factory AnalyzeCommandConfigs.fromYaml(
    Map<Object?, Object?> yaml, {
    required String workspacePath,
  }) {
    final hooksMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'hooks',
      map: yaml,
      path: 'command/analyze',
    );
    final hooks = hooksMap != null
        ? LifecycleHooks.fromYaml(hooksMap, workspacePath: workspacePath)
        : LifecycleHooks.empty;

    return AnalyzeCommandConfigs(
      hooks: hooks,
    );
  }

  static const AnalyzeCommandConfigs empty = AnalyzeCommandConfigs();

  /// Lifecycle hooks for this command.
  final LifecycleHooks hooks;

  Map<String, Object?> toJson() {
    return {
      'hooks': hooks.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is AnalyzeCommandConfigs &&
      other.runtimeType == runtimeType &&
      other.hooks == hooks;

  @override
  int get hashCode => runtimeType.hashCode ^ hooks.hashCode;

  @override
  String toString() {
    return '''
AnalyzeCommandConfigs(
  hooks: $hooks,
)''';
  }
}
