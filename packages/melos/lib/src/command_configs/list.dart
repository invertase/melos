import 'package:meta/meta.dart';

import '../common/list_output_kind.dart';
import '../common/validation.dart';

/// The output formats that can be configured as the default for
/// `melos list` and `melos changed`.
const _configurableListFormats = {
  'column': ListOutputKind.column,
  'parsable': ListOutputKind.parsable,
  'json': ListOutputKind.json,
  'graph': ListOutputKind.graph,
  'gviz': ListOutputKind.gviz,
  'mermaid': ListOutputKind.mermaid,
};

/// Configurations for `melos list` and `melos changed`.
@immutable
class ListCommandConfigs {
  const ListCommandConfigs({
    this.long,
    this.relativePaths,
    this.format,
  });

  factory ListCommandConfigs.fromYaml(Map<Object?, Object?> yaml) {
    final long = assertKeyIsA<bool?>(
      key: 'long',
      map: yaml,
      path: 'command/list',
    );

    final relativePaths = assertKeyIsA<bool?>(
      key: 'relativePaths',
      map: yaml,
      path: 'command/list',
    );

    final formatName = assertKeyIsA<String?>(
      key: 'format',
      map: yaml,
      path: 'command/list',
    );
    final format = formatName == null
        ? null
        : _configurableListFormats[formatName] ??
              (throw MelosConfigException(
                'The value at "command/list/format" must be one of '
                '${_configurableListFormats.keys.join(', ')} '
                'but got "$formatName".',
              ));

    return ListCommandConfigs(
      long: long,
      relativePaths: relativePaths,
      format: format,
    );
  }

  static const ListCommandConfigs empty = ListCommandConfigs();

  /// Whether to show extended information.
  ///
  /// The default is `false`.
  final bool? long;

  /// Whether to print package paths relative to the root of the workspace.
  ///
  /// The default is `false`.
  final bool? relativePaths;

  /// The output format to use.
  ///
  /// The default is [ListOutputKind.column].
  final ListOutputKind? format;

  Map<String, Object?> toJson() {
    return {
      if (long != null) 'long': long,
      if (relativePaths != null) 'relativePaths': relativePaths,
      if (format != null) 'format': format!.name,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ListCommandConfigs &&
      other.runtimeType == runtimeType &&
      other.long == long &&
      other.relativePaths == relativePaths &&
      other.format == format;

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    long,
    relativePaths,
    format,
  ]);

  @override
  String toString() {
    return '''
ListCommandConfigs(
  long: $long,
  relativePaths: $relativePaths,
  format: ${format?.name},
)''';
  }
}
