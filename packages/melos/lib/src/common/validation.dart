/// Utilities for decoding JSON/YAML and converting them into type-safe objects.
library validation;

import 'exception.dart';

T assertIsA<T>({
  int? index,
  Object? key,
  String? path,
  required Object? value,
}) {
  if (value is T) return value;

  throw MelosConfigException.invalidType(
    index: index,
    key: key,
    path: path,
    expectedType: T,
    value: value,
  );
}

T assertKeyIsA<T>({
  String? path,
  required Object key,
  required Map<Object?, Object?> map,
}) {
  if (null is! T && !map.containsKey(key)) {
    throw MelosConfigException.missingKey(key: key, path: path);
  }

  final value = map[key];
  return assertIsA<T>(value: value, key: key);
}

List<String> assertListOrString({
  String? path,
  required Object key,
  required Map<Object?, Object?> map,
  bool isRequired = false,
}) {
  final value = map[key];

  if (value == null) {
    if (isRequired) throw MelosConfigException.missingKey(key: key, path: path);
    return [];
  }

  if (value is String) {
    return [value];
  }

  return assertListIsA<String>(
    key: key,
    map: map,
    isRequired: isRequired,
    path: path,
    assertItemIsA: (index, item) {
      return assertIsA<String>(
        value: item,
        index: index,
        path: path == null ? '$key' : '$path/$key',
      );
    },
  );
}

List<T> assertListIsA<T>({
  String? path,
  required Object key,
  required Map<Object?, Object?> map,
  required bool isRequired,
  required T Function(int index, Object? value) assertItemIsA,
}) {
  final collection = assertKeyIsA<Iterable<Object?>?>(key: key, map: map);

  if (isRequired && collection == null) {
    throw MelosConfigException.missingKey(key: key, path: path);
  }

  if (collection != null && collection.isEmpty) {
    throw MelosConfigException(
      'The $key list is empty but at least one value was expected.',
    );
  }

  return <T>[
    for (var i = 0; collection != null && i < collection.length; i++)
      assertItemIsA(i, collection.elementAt(i)),
  ];
}

/// Thrown when `melos.yaml` configuration is malformed.
class MelosConfigException implements MelosException {
  MelosConfigException(this.message);

  MelosConfigException.missingKey({
    Object? key,
    int? index,
    String? path,
  }) : this('${_descriptor(key: key, index: index, path: path)} is required but missing');

  MelosConfigException.invalidType({
    required Object expectedType,
    Object? key,
    int? index,
    required Object? value,
    String? path,
  }) : this('${_descriptor(key: key, index: index, path: path)} is expected to be a $expectedType but got $value');

  static String _descriptor({Object? key, String? path, int? index}) {
    if (key != null) {
      if (path == null) return 'The property $key';
      return 'The property $key at $path';
    }
    if (index != null) {
      if (path == null) return 'The index $index';
      return 'The index $index at $path';
    }

    throw UnimplementedError();
  }

  final String message;

  @override
  String toString() => 'melos.yaml: $message';
}
