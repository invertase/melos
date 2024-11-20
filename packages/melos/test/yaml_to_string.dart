final _unsuportedCharacters = RegExp(
  r'''^[\n\t ,[\]{}#&*!|<>'"%@']|^[?-]$|^[?-][ \t]|[\n:][ \t]|[ \t]\n|[\n\t ]#|[\n\t :]$''',
);

/// This class is used to convert a YAML object to a YAML formatted string and
/// then write it to a sink.
class YamlToString {
  const YamlToString({
    this.indent = ' ',
    this.quotes = "'",
  });

  final String indent;
  final String quotes;
  static const _divider = ': ';

  String toYamlString(Object? node) {
    final stringBuffer = StringBuffer();
    writeYamlString(node, stringBuffer);
    return stringBuffer.toString();
  }

  /// Serializes [node] into a String and writes it to the [sink].
  void writeYamlString(Object? node, StringSink sink) {
    _writeYamlString(node, 0, sink, true);
  }

  void _writeYamlString(
    Object? node,
    int indentCount,
    StringSink stringSink,
    bool isTopLevel,
  ) {
    if (node is Map) {
      _mapToYamlString(
        node as Map<String, Object?>,
        indentCount,
        stringSink,
        isTopLevel,
      );
    } else if (node is Iterable) {
      _listToYamlString(node, indentCount, stringSink, isTopLevel);
    } else if (node is String) {
      stringSink.writeln(_escapeString(node));
    } else if (node is double) {
      stringSink.writeln('!!float $node');
    } else {
      stringSink.writeln(node);
    }
  }

  String _escapeString(String line) {
    var escapedLine = line.replaceAll('"', r'\"').replaceAll('\n', r'\n');

    if (escapedLine.contains(_unsuportedCharacters)) {
      escapedLine = quotes + escapedLine + quotes;
    }

    return escapedLine;
  }

  void _mapToYamlString(
    Map<String, Object?> node,
    int indentCount,
    StringSink stringSink,
    bool isTopLevel,
  ) {
    final totalIndentCount = isTopLevel ? indentCount : indentCount + 2;
    if (!isTopLevel) {
      stringSink.writeln();
    }

    final keys = _sortKeys(node);

    for (final key in keys) {
      final value = node[key];
      _writeIndent(totalIndentCount, stringSink);
      stringSink
        ..write(key)
        ..write(_divider);
      _writeYamlString(value, totalIndentCount, stringSink, false);
    }
  }

  Iterable<String> _sortKeys(Map<String, Object?> map) {
    final simple = <String>[];
    final maps = <String>[];
    final lists = <String>[];
    final other = <String>[];

    map.forEach((key, value) {
      if (value is String) {
        simple.add(key);
      } else if (value is Map) {
        maps.add(key);
      } else if (value is Iterable) {
        lists.add(key);
      } else {
        other.add(key);
      }
    });

    return [...simple, ...maps, ...lists, ...other];
  }

  void _listToYamlString(
    Iterable<Object?> node,
    int indentCount,
    StringSink stringSink,
    bool isTopLevel,
  ) {
    final totalIndentCount = isTopLevel ? indentCount : indentCount + 2;
    if (!isTopLevel) {
      stringSink.writeln();
    }

    for (final value in node) {
      _writeIndent(totalIndentCount, stringSink);
      stringSink.write('- ');
      _writeYamlString(value, totalIndentCount, stringSink, false);
    }
  }

  void _writeIndent(int indentCount, StringSink stringSink) =>
      stringSink.write(indent * indentCount);
}
