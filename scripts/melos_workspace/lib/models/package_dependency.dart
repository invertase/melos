import 'package:freezed_annotation/freezed_annotation.dart';

part 'package_dependency.freezed.dart';
part 'package_dependency.g.dart';

@freezed
class PackageDependency with _$PackageDependency {
  @JsonSerializable()
  const factory PackageDependency({
    @JsonKey(name: 'name') required String name,
    @JsonKey(name: 'content_type') required String contentType,
    @JsonKey(name: 'private') required bool private,
    @JsonKey(name: 'location') required String location,
    @JsonKey(name: 'type') required int type,
  }) = _PackageDependency;

  factory PackageDependency.fromJson(Map<String, dynamic> json) =>
      _$PackageDependencyFromJson(json);
}
