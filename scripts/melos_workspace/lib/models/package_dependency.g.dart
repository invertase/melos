// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'package_dependency.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_PackageDependency _$$_PackageDependencyFromJson(Map<String, dynamic> json) =>
    _$_PackageDependency(
      name: json['name'] as String,
      contentType: json['version'] as String,
      private: json['private'] as bool,
      location: json['location'] as String,
      type: json['type'] as int,
    );

Map<String, dynamic> _$$_PackageDependencyToJson(
        _$_PackageDependency instance) =>
    <String, dynamic>{
      'name': instance.name,
      'version': instance.contentType,
      'private': instance.private,
      'location': instance.location,
      'type': instance.type,
    };
