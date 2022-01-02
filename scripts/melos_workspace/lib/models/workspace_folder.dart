import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace_folder.freezed.dart';
part 'workspace_folder.g.dart';

@freezed
class WorkspaceFolder with _$WorkspaceFolder {
  @JsonSerializable()
  const factory WorkspaceFolder({
    required String name,
    required String path,
  }) = _WorkspaceFolder;

  factory WorkspaceFolder.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceFolderFromJson(json);
}
