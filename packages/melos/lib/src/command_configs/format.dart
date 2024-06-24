import 'package:meta/meta.dart';

import '../common/validation.dart';
import '../lifecycle_hooks/lifecycle_hooks.dart';

/// Configurations for `melos format`.
@immutable
class FormatCommandConfigs {
  const FormatCommandConfigs({
    this.setExitIfChanged,
    this.lineLength,
    this.hooks = LifecycleHooks.empty,
  });

  factory FormatCommandConfigs.fromYaml(
    Map<Object?, Object?> yaml, {
    required String workspacePath,
  }) {
    final setExitIfChanged = assertKeyIsA<bool?>(
      key: 'setExitIfChanged',
      map: yaml,
      path: 'command/format',
    );

    final lineLength = assertKeyIsA<int?>(
      key: 'lineLength',
      map: yaml,
      path: 'command/format',
    );

    final hooksMap = assertKeyIsA<Map<Object?, Object?>?>(
      key: 'hooks',
      map: yaml,
      path: 'command/format',
    );
    final hooks = hooksMap != null
        ? LifecycleHooks.fromYaml(hooksMap, workspacePath: workspacePath)
        : LifecycleHooks.empty;

    return FormatCommandConfigs(
      setExitIfChanged: setExitIfChanged,
      lineLength: lineLength,
      hooks: hooks,
    );
  }

  static const FormatCommandConfigs empty = FormatCommandConfigs();

  /// Declares if `--set-exit-if-changed` flag is passed
  /// to the `dart format` command.
  final bool? setExitIfChanged;

  /// The `--line-length` passed to the `dart format` command.
  final int? lineLength;

  /// Lifecycle hooks for this command.
  final LifecycleHooks hooks;

  Map<String, Object?> toJson() {
    return {
      if (lineLength != null) 'lineLength': lineLength,
      if (setExitIfChanged != null) 'setExitIfChanged': setExitIfChanged,
      'hooks': hooks.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is FormatCommandConfigs &&
      other.runtimeType == runtimeType &&
      other.setExitIfChanged == setExitIfChanged &&
      other.lineLength == lineLength &&
      other.hooks == hooks;

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      setExitIfChanged.hashCode ^
      lineLength.hashCode ^
      hooks.hashCode;

  @override
  String toString() {
    return '''
FormatCommandConfigs(
  setExitIfChanged: $setExitIfChanged,
  lineLength: $lineLength,
  hooks: $hooks,
)''';
  }
}
