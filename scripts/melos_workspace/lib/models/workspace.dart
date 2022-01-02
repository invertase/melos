import 'package:freezed_annotation/freezed_annotation.dart';

import 'workspace_folder.dart';

part 'workspace.freezed.dart';
part 'workspace.g.dart';

@freezed
class Workspace with _$Workspace {
  @JsonSerializable(
    explicitToJson: true,
  )
  const factory Workspace({
    @JsonKey(name: 'folders') required List<WorkspaceFolder> folders,
  }) = _Workspace;

  factory Workspace.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceFromJson(json);
}
