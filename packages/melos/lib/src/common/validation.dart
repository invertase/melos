/// Utilities for decoding JSON/YAML and converting them into type-safe objects.
library validation;

import 'exception.dart';

T assertIsA<T>({
  required Object? value,
  int? index,
  Object? key,
  String? path,
}) {
  if (value is T) {
    return value;
  }

  throw MelosConfigException.invalidType(
    index: index,
    key: key,
    path: path,
    expectedType: T,
    value: value,
  );
}

T assertKeyIsA<T>({
  required Object key,
  required Map<Object?, Object?> map,
  String? path,
}) {
  if (null is! T && !map.containsKey(key)) {
    throw MelosConfigException.missingKey(key: key, path: path);
  }

  return assertIsA<T>(value: map[key], key: key);
}

List<String> assertListOrString({
  required Object key,
  required Map<Object?, Object?> map,
  String? path,
  bool isRequired = false,
}) {
  final value = map[key];

  if (value == null) {
    if (isRequired) {
      throw MelosConfigException.missingKey(key: key, path: path);
    }
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
  required Object key,
  required Map<Object?, Object?> map,
  required bool isRequired,
  required T Function(int index, Object? value) assertItemIsA,
  String? path,
}) {
  final collection = assertKeyIsA<Iterable<Object?>?>(key: key, map: map);

  if (isRequired && collection == null) {
    throw MelosConfigException.missingKey(key: key, path: path);
  }

  if (isRequired && collection != null && collection.isEmpty) {
    throw MelosConfigException(
      'The $key list is empty but at least one value was expected.',
    );
  }

  return <T>[
    for (var i = 0; collection != null && i < collection.length; i++)
      assertItemIsA(i, collection.elementAt(i)),
  ];
}

Map<T, V> assertMapIsA<T, V>({
  required Object key,
  required Map<Object?, Object?> map,
  required bool isRequired,
  required T Function(Object? value) assertKey,
  required V Function(Object? key, Object? value) assertValue,
  String? path,
}) {
  final collection = assertKeyIsA<Map<Object?, Object?>?>(key: key, map: map);

  if (isRequired && collection == null) {
    throw MelosConfigException.missingKey(key: key, path: path);
  }

  return <T, V>{
    for (final entry in collection?.entries ?? <MapEntry<Object?, Object?>>[])
      assertKey(entry.key): assertValue(entry.key, entry.value),
  };
}

/// Thrown when the melos section of the root `pubspec.yaml` configuration is
/// malformed.
class MelosConfigException implements MelosException {
  MelosConfigException(this.message);

  MelosConfigException.missingKey({
    Object? key,
    int? index,
    String? path,
  }) : this(
         '${_descriptor(key: key, index: index, path: path)} '
         'is required but missing',
       );

  MelosConfigException.invalidType({
    required Object expectedType,
    required Object? value,
    Object? key,
    int? index,
    String? path,
  }) : this(
         '${_descriptor(key: key, index: index, path: path)} '
         'is expected to be a $expectedType but got $value',
       );

  static String _descriptor({Object? key, String? path, int? index}) {
    if (key != null) {
      if (path == null) {
        return 'The property $key';
      }
      return 'The property $key at $path';
    }
    if (index != null) {
      if (path == null) {
        return 'The index $index';
      }
      return 'The index $index at $path';
    }

    throw UnimplementedError();
  }

  final String message;

  @override
  String toString() => 'pubspec.yaml: $message';
}
