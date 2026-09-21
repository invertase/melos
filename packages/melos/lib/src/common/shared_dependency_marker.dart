import 'package:yaml/yaml.dart';

/// The comment that marks an entry of a `pubspec.yaml` file as being synced
/// from the shared dependencies of the bootstrap config.
const sharedDependencyMarker =
    '# Managed by Melos, change it in the bootstrap config of the root '
    'pubspec.yaml';

final _sharedDependencyMarkerPattern = RegExp(
  '[ \\t]*${RegExp.escape(sharedDependencyMarker)}(?=[ \\t]*\\r?(?:\\n|\$))',
);

/// Returns [pubspecContent] where exactly the entries in [sharedKeys] are
/// followed by the [sharedDependencyMarker] comment.
///
/// [sharedKeys] maps a section of the pubspec, like `dependencies`, to the keys
/// within that section that are shared. Keys that do not exist in the pubspec
/// are ignored.
///
/// Markers on entries that are not in [sharedKeys] are removed, so the result
/// only depends on [sharedKeys] and not on the markers of previous runs.
String applySharedDependencyMarkers(
  String pubspecContent, {
  required Map<String, Iterable<String>> sharedKeys,
}) {
  var content = pubspecContent.replaceAll(_sharedDependencyMarkerPattern, '');
  if (sharedKeys.isEmpty) {
    return content;
  }

  final pubspec = loadYamlNode(content);
  if (pubspec is! YamlMap) {
    return content;
  }

  final markerOffsets = <int>{};
  for (final MapEntry(key: section, value: keys) in sharedKeys.entries) {
    final entries = pubspec.nodes[section];
    if (entries is! YamlMap) {
      continue;
    }
    for (final MapEntry(:key as YamlNode, :value) in entries.nodes.entries) {
      if (!keys.contains(key.value)) {
        continue;
      }
      final anchor = _acceptsCommentOnlyAfterLastLine(value)
          ? value.span.end.offset
          : key.span.end.offset;
      final newline = content.indexOf('\n', anchor);
      final lineEnd = newline == -1 ? content.length : newline;
      final line = content.substring(anchor, lineEnd);
      markerOffsets.add(anchor + line.trimRight().length);
    }
  }

  for (final offset in markerOffsets.toList()..sort((a, b) => b - a)) {
    content = content.replaceRange(offset, offset, ' $sharedDependencyMarker');
  }
  return content;
}

bool _acceptsCommentOnlyAfterLastLine(YamlNode node) {
  if (node is! YamlScalar || node.span.length == 0) {
    return false;
  }
  return switch (node.style) {
    ScalarStyle.PLAIN ||
    ScalarStyle.SINGLE_QUOTED ||
    ScalarStyle.DOUBLE_QUOTED => true,
    _ => false,
  };
}
