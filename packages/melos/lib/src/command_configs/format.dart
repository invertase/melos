import 'package:meta/meta.dart';

import '../common/validation.dart';

/// Configurations for `melos format`.
@immutable
class FormatCommandConfigs {
  const FormatCommandConfigs({
    this.setExitIfChanged,
    this.lineLength,
  });

  factory FormatCommandConfigs.fromYaml(
    Map<Object?, Object?> yaml,
  ) {
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

    return FormatCommandConfigs(
      setExitIfChanged: setExitIfChanged,
      lineLength: lineLength,
    );
  }

  static const FormatCommandConfigs empty = FormatCommandConfigs();

  /// Declares if `--set-exit-if-changed` flag is passed
  /// to the `dart format` command.
  final bool? setExitIfChanged;

  /// The `--line-length` passed to the `dart format` command.
  final int? lineLength;

  Map<String, Object?> toJson() {
    return {
      if (lineLength != null) 'lineLength': lineLength,
      if (setExitIfChanged != null) 'setExitIfChanged': setExitIfChanged,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is FormatCommandConfigs &&
      other.runtimeType == runtimeType &&
      other.setExitIfChanged == setExitIfChanged &&
      other.lineLength == lineLength;

  @override
  int get hashCode =>
      runtimeType.hashCode ^ setExitIfChanged.hashCode ^ lineLength.hashCode;

  @override
  String toString() {
    return '''
FormatCommandConfigs(
  setExitIfChanged: $setExitIfChanged,
  lineLength: $lineLength,
)''';
  }
}
