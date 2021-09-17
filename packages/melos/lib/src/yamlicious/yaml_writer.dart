// Copyright (c) 2015, Anders Holmgren. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library yaml.writer;

/// Serializes [node] into a String and returns it.
String toYamlString(dynamic node) {
  final sb = StringBuffer();
  writeYamlString(node, sb);
  return sb.toString();
}

/// Serializes [node] into a String and writes it to the [sink].
void writeYamlString(dynamic node, StringSink sink) {
  _writeYamlString(node, 0, sink, true);
}

void _writeYamlString(
  dynamic node,
  int indent,
  StringSink ss,
  bool isTopLevel,
) {
  if (node is Map) {
    _mapToYamlString(Map<String, Object?>.from(node), indent, ss, isTopLevel);
  } else if (node is Iterable) {
    _listToYamlString(node, indent, ss, isTopLevel);
  } else if (node is String) {
    ss.writeln('"${_escapeString(node)}"');
  } else if (node is double) {
    ss.writeln('!!float $node');
  } else {
    ss.writeln(node);
  }
}

String _escapeString(String s) =>
    s.replaceAll('"', r'\"').replaceAll('\n', r'\n');

void _mapToYamlString(
  Map<String, Object?> node,
  int indent,
  StringSink ss,
  bool isTopLevel,
) {
  if (!isTopLevel) {
    ss.writeln();
    // ignore: parameter_assignments
    indent += 2;
  }

  final keys = _sortKeys(node);

  // ignore: avoid_function_literals_in_foreach_calls
  keys.forEach((k) {
    final dynamic v = node[k];
    _writeIndent(indent, ss);
    ss
      ..write(k)
      ..write(': ');
    _writeYamlString(v, indent, ss, false);
  });
}

Iterable<String> _sortKeys(Map<String, Object?> m) {
  final simple = <String>[];
  final maps = <String>[];
  final other = <String>[];

  m.forEach((String k, dynamic v) {
    if (v is String) {
      simple.add(k);
    } else if (v is Map) {
      maps.add(k);
    } else {
      other.add(k);
    }
  });

  return [
    ...simple..sort(),
    ...maps..sort(),
    ...other..sort(),
  ];
}

void _listToYamlString(
  Iterable node,
  int indent,
  StringSink ss,
  bool isTopLevel,
) {
  if (!isTopLevel) {
    ss.writeln();
    // ignore: parameter_assignments
    indent += 2;
  }

  // ignore: avoid_function_literals_in_foreach_calls
  node.forEach((dynamic v) {
    _writeIndent(indent, ss);
    ss.write('- ');
    _writeYamlString(v, indent, ss, false);
  });
}

void _writeIndent(int indent, StringSink ss) => ss.write(' ' * indent);
