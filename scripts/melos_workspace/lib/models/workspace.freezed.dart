// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target

part of 'workspace.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more informations: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

Workspace _$WorkspaceFromJson(Map<String, dynamic> json) {
  return _Workspace.fromJson(json);
}

/// @nodoc
class _$WorkspaceTearOff {
  const _$WorkspaceTearOff();

  _Workspace call(
      {@JsonKey(name: 'folders') required List<WorkspaceFolder> folders}) {
    return _Workspace(
      folders: folders,
    );
  }

  Workspace fromJson(Map<String, Object?> json) {
    return Workspace.fromJson(json);
  }
}

/// @nodoc
const $Workspace = _$WorkspaceTearOff();

/// @nodoc
mixin _$Workspace {
  @JsonKey(name: 'folders')
  List<WorkspaceFolder> get folders => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $WorkspaceCopyWith<Workspace> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkspaceCopyWith<$Res> {
  factory $WorkspaceCopyWith(Workspace value, $Res Function(Workspace) then) =
      _$WorkspaceCopyWithImpl<$Res>;
  $Res call({@JsonKey(name: 'folders') List<WorkspaceFolder> folders});
}

/// @nodoc
class _$WorkspaceCopyWithImpl<$Res> implements $WorkspaceCopyWith<$Res> {
  _$WorkspaceCopyWithImpl(this._value, this._then);

  final Workspace _value;
  // ignore: unused_field
  final $Res Function(Workspace) _then;

  @override
  $Res call({
    Object? folders = freezed,
  }) {
    return _then(_value.copyWith(
      folders: folders == freezed
          ? _value.folders
          : folders // ignore: cast_nullable_to_non_nullable
              as List<WorkspaceFolder>,
    ));
  }
}

/// @nodoc
abstract class _$WorkspaceCopyWith<$Res> implements $WorkspaceCopyWith<$Res> {
  factory _$WorkspaceCopyWith(
          _Workspace value, $Res Function(_Workspace) then) =
      __$WorkspaceCopyWithImpl<$Res>;
  @override
  $Res call({@JsonKey(name: 'folders') List<WorkspaceFolder> folders});
}

/// @nodoc
class __$WorkspaceCopyWithImpl<$Res> extends _$WorkspaceCopyWithImpl<$Res>
    implements _$WorkspaceCopyWith<$Res> {
  __$WorkspaceCopyWithImpl(_Workspace _value, $Res Function(_Workspace) _then)
      : super(_value, (v) => _then(v as _Workspace));

  @override
  _Workspace get _value => super._value as _Workspace;

  @override
  $Res call({
    Object? folders = freezed,
  }) {
    return _then(_Workspace(
      folders: folders == freezed
          ? _value.folders
          : folders // ignore: cast_nullable_to_non_nullable
              as List<WorkspaceFolder>,
    ));
  }
}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _$_Workspace implements _Workspace {
  const _$_Workspace({@JsonKey(name: 'folders') required this.folders});

  factory _$_Workspace.fromJson(Map<String, dynamic> json) =>
      _$$_WorkspaceFromJson(json);

  @override
  @JsonKey(name: 'folders')
  final List<WorkspaceFolder> folders;

  @override
  String toString() {
    return 'Workspace(folders: $folders)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Workspace &&
            const DeepCollectionEquality().equals(other.folders, folders));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(folders));

  @JsonKey(ignore: true)
  @override
  _$WorkspaceCopyWith<_Workspace> get copyWith =>
      __$WorkspaceCopyWithImpl<_Workspace>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_WorkspaceToJson(this);
  }
}

abstract class _Workspace implements Workspace {
  const factory _Workspace(
          {@JsonKey(name: 'folders') required List<WorkspaceFolder> folders}) =
      _$_Workspace;

  factory _Workspace.fromJson(Map<String, dynamic> json) =
      _$_Workspace.fromJson;

  @override
  @JsonKey(name: 'folders')
  List<WorkspaceFolder> get folders;
  @override
  @JsonKey(ignore: true)
  _$WorkspaceCopyWith<_Workspace> get copyWith =>
      throw _privateConstructorUsedError;
}
