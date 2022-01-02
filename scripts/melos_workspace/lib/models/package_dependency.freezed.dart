// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target

part of 'package_dependency.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more informations: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

PackageDependency _$PackageDependencyFromJson(Map<String, dynamic> json) {
  return _PackageDependency.fromJson(json);
}

/// @nodoc
class _$PackageDependencyTearOff {
  const _$PackageDependencyTearOff();

  _PackageDependency call(
      {@JsonKey(name: 'name') required String name,
      @JsonKey(name: 'version') required String contentType,
      @JsonKey(name: 'private') required bool private,
      @JsonKey(name: 'location') required String location,
      @JsonKey(name: 'type') required int type}) {
    return _PackageDependency(
      name: name,
      contentType: contentType,
      private: private,
      location: location,
      type: type,
    );
  }

  PackageDependency fromJson(Map<String, Object?> json) {
    return PackageDependency.fromJson(json);
  }
}

/// @nodoc
const $PackageDependency = _$PackageDependencyTearOff();

/// @nodoc
mixin _$PackageDependency {
  @JsonKey(name: 'name')
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'version')
  String get contentType => throw _privateConstructorUsedError;
  @JsonKey(name: 'private')
  bool get private => throw _privateConstructorUsedError;
  @JsonKey(name: 'location')
  String get location => throw _privateConstructorUsedError;
  @JsonKey(name: 'type')
  int get type => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PackageDependencyCopyWith<PackageDependency> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PackageDependencyCopyWith<$Res> {
  factory $PackageDependencyCopyWith(
          PackageDependency value, $Res Function(PackageDependency) then) =
      _$PackageDependencyCopyWithImpl<$Res>;
  $Res call(
      {@JsonKey(name: 'name') String name,
      @JsonKey(name: 'version') String contentType,
      @JsonKey(name: 'private') bool private,
      @JsonKey(name: 'location') String location,
      @JsonKey(name: 'type') int type});
}

/// @nodoc
class _$PackageDependencyCopyWithImpl<$Res>
    implements $PackageDependencyCopyWith<$Res> {
  _$PackageDependencyCopyWithImpl(this._value, this._then);

  final PackageDependency _value;
  // ignore: unused_field
  final $Res Function(PackageDependency) _then;

  @override
  $Res call({
    Object? name = freezed,
    Object? contentType = freezed,
    Object? private = freezed,
    Object? location = freezed,
    Object? type = freezed,
  }) {
    return _then(_value.copyWith(
      name: name == freezed
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      contentType: contentType == freezed
          ? _value.contentType
          : contentType // ignore: cast_nullable_to_non_nullable
              as String,
      private: private == freezed
          ? _value.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool,
      location: location == freezed
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String,
      type: type == freezed
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
abstract class _$PackageDependencyCopyWith<$Res>
    implements $PackageDependencyCopyWith<$Res> {
  factory _$PackageDependencyCopyWith(
          _PackageDependency value, $Res Function(_PackageDependency) then) =
      __$PackageDependencyCopyWithImpl<$Res>;
  @override
  $Res call(
      {@JsonKey(name: 'name') String name,
      @JsonKey(name: 'version') String contentType,
      @JsonKey(name: 'private') bool private,
      @JsonKey(name: 'location') String location,
      @JsonKey(name: 'type') int type});
}

/// @nodoc
class __$PackageDependencyCopyWithImpl<$Res>
    extends _$PackageDependencyCopyWithImpl<$Res>
    implements _$PackageDependencyCopyWith<$Res> {
  __$PackageDependencyCopyWithImpl(
      _PackageDependency _value, $Res Function(_PackageDependency) _then)
      : super(_value, (v) => _then(v as _PackageDependency));

  @override
  _PackageDependency get _value => super._value as _PackageDependency;

  @override
  $Res call({
    Object? name = freezed,
    Object? contentType = freezed,
    Object? private = freezed,
    Object? location = freezed,
    Object? type = freezed,
  }) {
    return _then(_PackageDependency(
      name: name == freezed
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      contentType: contentType == freezed
          ? _value.contentType
          : contentType // ignore: cast_nullable_to_non_nullable
              as String,
      private: private == freezed
          ? _value.private
          : private // ignore: cast_nullable_to_non_nullable
              as bool,
      location: location == freezed
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as String,
      type: type == freezed
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

@JsonSerializable()
class _$_PackageDependency implements _PackageDependency {
  const _$_PackageDependency(
      {@JsonKey(name: 'name') required this.name,
      @JsonKey(name: 'version') required this.contentType,
      @JsonKey(name: 'private') required this.private,
      @JsonKey(name: 'location') required this.location,
      @JsonKey(name: 'type') required this.type});

  factory _$_PackageDependency.fromJson(Map<String, dynamic> json) =>
      _$$_PackageDependencyFromJson(json);

  @override
  @JsonKey(name: 'name')
  final String name;
  @override
  @JsonKey(name: 'version')
  final String contentType;
  @override
  @JsonKey(name: 'private')
  final bool private;
  @override
  @JsonKey(name: 'location')
  final String location;
  @override
  @JsonKey(name: 'type')
  final int type;

  @override
  String toString() {
    return 'PackageDependency(name: $name, contentType: $contentType, private: $private, location: $location, type: $type)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PackageDependency &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.contentType, contentType) ||
                other.contentType == contentType) &&
            (identical(other.private, private) || other.private == private) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.type, type) || other.type == type));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, name, contentType, private, location, type);

  @JsonKey(ignore: true)
  @override
  _$PackageDependencyCopyWith<_PackageDependency> get copyWith =>
      __$PackageDependencyCopyWithImpl<_PackageDependency>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_PackageDependencyToJson(this);
  }
}

abstract class _PackageDependency implements PackageDependency {
  const factory _PackageDependency(
      {@JsonKey(name: 'name') required String name,
      @JsonKey(name: 'version') required String contentType,
      @JsonKey(name: 'private') required bool private,
      @JsonKey(name: 'location') required String location,
      @JsonKey(name: 'type') required int type}) = _$_PackageDependency;

  factory _PackageDependency.fromJson(Map<String, dynamic> json) =
      _$_PackageDependency.fromJson;

  @override
  @JsonKey(name: 'name')
  String get name;
  @override
  @JsonKey(name: 'version')
  String get contentType;
  @override
  @JsonKey(name: 'private')
  bool get private;
  @override
  @JsonKey(name: 'location')
  String get location;
  @override
  @JsonKey(name: 'type')
  int get type;
  @override
  @JsonKey(ignore: true)
  _$PackageDependencyCopyWith<_PackageDependency> get copyWith =>
      throw _privateConstructorUsedError;
}
