// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_Workspace _$$_WorkspaceFromJson(Map<String, dynamic> json) => _$_Workspace(
      folders: (json['folders'] as List<dynamic>)
          .map((e) => WorkspaceFolder.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$_WorkspaceToJson(_$_Workspace instance) =>
    <String, dynamic>{
      'folders': instance.folders.map((e) => e.toJson()).toList(),
    };
