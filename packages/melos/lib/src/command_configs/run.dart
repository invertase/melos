import 'package:meta/meta.dart';

import '../common/validation.dart';

/// Configurations for `melos run`.
@immutable
class RunCommandConfigs {
  const RunCommandConfigs({
    this.noSelect,
  });

  factory RunCommandConfigs.fromYaml(Map<Object?, Object?> yaml) {
    final noSelect = assertKeyIsA<bool?>(
      key: 'noSelect',
      map: yaml,
      path: 'command/run',
    );

    return RunCommandConfigs(
      noSelect: noSelect,
    );
  }

  static const RunCommandConfigs empty = RunCommandConfigs();

  /// Whether to skip the prompt that asks for the package to run a script in,
  /// when the script defines `packageFilters`. The filters themselves are
  /// still applied.
  ///
  /// The default is `false`.
  final bool? noSelect;

  Map<String, Object?> toJson() {
    return {
      if (noSelect != null) 'noSelect': noSelect,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is RunCommandConfigs &&
      other.runtimeType == runtimeType &&
      other.noSelect == noSelect;

  @override
  int get hashCode => Object.hashAll([runtimeType, noSelect]);

  @override
  String toString() {
    return '''
RunCommandConfigs(
  noSelect: $noSelect,
)''';
  }
}
