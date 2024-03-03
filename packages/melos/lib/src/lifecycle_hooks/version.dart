import 'package:meta/meta.dart';

import '../../melos.dart';
import 'lifecycle_hooks.dart';

/// [LifecycleHooks] for the `version` command.
@immutable
class VersionLifecycleHooks extends LifecycleHooks {
  const VersionLifecycleHooks({super.pre, super.post, this.preCommit});

  factory VersionLifecycleHooks.fromYaml(
    Map<Object?, Object?> yaml, {
    required String workspacePath,
  }) {
    return VersionLifecycleHooks(
      pre: Script.fromName('pre', yaml, workspacePath),
      post: Script.fromName('post', yaml, workspacePath),
      preCommit: Script.fromName('preCommit', yaml, workspacePath),
    );
  }

  /// A script to execute before the version command commits the the changes
  /// made during versioning.
  final Script? preCommit;

  static const VersionLifecycleHooks empty = VersionLifecycleHooks();

  @override
  Map<String, Object?> toJson() {
    return {
      ...super.toJson(),
      'preCommit': preCommit?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is VersionLifecycleHooks &&
      runtimeType == other.runtimeType &&
      other.pre == pre &&
      other.post == post &&
      other.preCommit == preCommit;

  @override
  int get hashCode =>
      runtimeType.hashCode ^ pre.hashCode ^ post.hashCode ^ preCommit.hashCode;

  @override
  String toString() {
    return '''
VersionLifecycleHooks(
  pre: $pre,
  post: $post,
  preCommit: $preCommit,
)
''';
  }
}
