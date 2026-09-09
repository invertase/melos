import 'package:meta/meta.dart';

import '../common/validation.dart';

/// Configurations for `melos format`.
@immutable
class FormatCommandConfigs {
  const FormatCommandConfigs({
    this.concurrency,
    this.setExitIfChanged,
    this.output,
    this.lineLength,
  });

  factory FormatCommandConfigs.fromYaml(
    Map<Object?, Object?> yaml,
  ) {
    final concurrency = assertKeyIsA<int?>(
      key: 'concurrency',
      map: yaml,
      path: 'command/format',
    );

    final setExitIfChanged = assertKeyIsA<bool?>(
      key: 'setExitIfChanged',
      map: yaml,
      path: 'command/format',
    );

    final output = assertKeyIsA<String?>(
      key: 'output',
      map: yaml,
      path: 'command/format',
    );

    final lineLength = assertKeyIsA<int?>(
      key: 'lineLength',
      map: yaml,
      path: 'command/format',
    );

    return FormatCommandConfigs(
      concurrency: concurrency,
      setExitIfChanged: setExitIfChanged,
      output: output,
      lineLength: lineLength,
    );
  }

  static const FormatCommandConfigs empty = FormatCommandConfigs();

  /// The number of packages to format concurrently.
  ///
  /// The default is `1`.
  final int? concurrency;

  /// Declares if `--set-exit-if-changed` flag is passed
  /// to the `dart format` command.
  final bool? setExitIfChanged;

  /// Where the `dart format` command writes its output to.
  final String? output;

  /// The `--line-length` passed to the `dart format` command.
  final int? lineLength;

  Map<String, Object?> toJson() {
    return {
      if (concurrency != null) 'concurrency': concurrency,
      if (lineLength != null) 'lineLength': lineLength,
      if (output != null) 'output': output,
      if (setExitIfChanged != null) 'setExitIfChanged': setExitIfChanged,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is FormatCommandConfigs &&
      other.runtimeType == runtimeType &&
      other.concurrency == concurrency &&
      other.setExitIfChanged == setExitIfChanged &&
      other.output == output &&
      other.lineLength == lineLength;

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    concurrency,
    setExitIfChanged,
    output,
    lineLength,
  ]);

  @override
  String toString() {
    return '''
FormatCommandConfigs(
  concurrency: $concurrency,
  setExitIfChanged: $setExitIfChanged,
  output: $output,
  lineLength: $lineLength,
)''';
  }
}
