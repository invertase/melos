// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target

part of 'workspace_folder.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more informations: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

WorkspaceFolder _$WorkspaceFolderFromJson(Map<String, dynamic> json) {
  return _WorkspaceFolder.fromJson(json);
}

/// @nodoc
class _$WorkspaceFolderTearOff {
  const _$WorkspaceFolderTearOff();

  _WorkspaceFolder call(
      {@JsonKey(name: 'name') required String name,
      @JsonKey(name: 'path') required String path}) {
    return _WorkspaceFolder(
      name: name,
      path: path,
    );
  }

  WorkspaceFolder fromJson(Map<String, Object?> json) {
    return WorkspaceFolder.fromJson(json);
  }
}

/// @nodoc
const $WorkspaceFolder = _$WorkspaceFolderTearOff();

/// @nodoc
mixin _$WorkspaceFolder {
  @JsonKey(name: 'name')
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'path')
  String get path => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $WorkspaceFolderCopyWith<WorkspaceFolder> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkspaceFolderCopyWith<$Res> {
  factory $WorkspaceFolderCopyWith(
          WorkspaceFolder value, $Res Function(WorkspaceFolder) then) =
      _$WorkspaceFolderCopyWithImpl<$Res>;
  $Res call(
      {@JsonKey(name: 'name') String name, @JsonKey(name: 'path') String path});
}

/// @nodoc
class _$WorkspaceFolderCopyWithImpl<$Res>
    implements $WorkspaceFolderCopyWith<$Res> {
  _$WorkspaceFolderCopyWithImpl(this._value, this._then);

  final WorkspaceFolder _value;
  // ignore: unused_field
  final $Res Function(WorkspaceFolder) _then;

  @override
  $Res call({
    Object? name = freezed,
    Object? path = freezed,
  }) {
    return _then(_value.copyWith(
      name: name == freezed
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      path: path == freezed
          ? _value.path
          : path // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
abstract class _$WorkspaceFolderCopyWith<$Res>
    implements $WorkspaceFolderCopyWith<$Res> {
  factory _$WorkspaceFolderCopyWith(
          _WorkspaceFolder value, $Res Function(_WorkspaceFolder) then) =
      __$WorkspaceFolderCopyWithImpl<$Res>;
  @override
  $Res call(
      {@JsonKey(name: 'name') String name, @JsonKey(name: 'path') String path});
}

/// @nodoc
class __$WorkspaceFolderCopyWithImpl<$Res>
    extends _$WorkspaceFolderCopyWithImpl<$Res>
    implements _$WorkspaceFolderCopyWith<$Res> {
  __$WorkspaceFolderCopyWithImpl(
      _WorkspaceFolder _value, $Res Function(_WorkspaceFolder) _then)
      : super(_value, (v) => _then(v as _WorkspaceFolder));

  @override
  _WorkspaceFolder get _value => super._value as _WorkspaceFolder;

  @override
  $Res call({
    Object? name = freezed,
    Object? path = freezed,
  }) {
    return _then(_WorkspaceFolder(
      name: name == freezed
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      path: path == freezed
          ? _value.path
          : path // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

@JsonSerializable()
class _$_WorkspaceFolder implements _WorkspaceFolder {
  const _$_WorkspaceFolder(
      {@JsonKey(name: 'name') required this.name,
      @JsonKey(name: 'path') required this.path});

  factory _$_WorkspaceFolder.fromJson(Map<String, dynamic> json) =>
      _$$_WorkspaceFolderFromJson(json);

  @override
  @JsonKey(name: 'name')
  final String name;
  @override
  @JsonKey(name: 'path')
  final String path;

  @override
  String toString() {
    return 'WorkspaceFolder(name: $name, path: $path)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _WorkspaceFolder &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.path, path) || other.path == path));
  }

  @override
  int get hashCode => Object.hash(runtimeType, name, path);

  @JsonKey(ignore: true)
  @override
  _$WorkspaceFolderCopyWith<_WorkspaceFolder> get copyWith =>
      __$WorkspaceFolderCopyWithImpl<_WorkspaceFolder>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_WorkspaceFolderToJson(this);
  }
}

abstract class _WorkspaceFolder implements WorkspaceFolder {
  const factory _WorkspaceFolder(
      {@JsonKey(name: 'name') required String name,
      @JsonKey(name: 'path') required String path}) = _$_WorkspaceFolder;

  factory _WorkspaceFolder.fromJson(Map<String, dynamic> json) =
      _$_WorkspaceFolder.fromJson;

  @override
  @JsonKey(name: 'name')
  String get name;
  @override
  @JsonKey(name: 'path')
  String get path;
  @override
  @JsonKey(ignore: true)
  _$WorkspaceFolderCopyWith<_WorkspaceFolder> get copyWith =>
      throw _privateConstructorUsedError;
}
