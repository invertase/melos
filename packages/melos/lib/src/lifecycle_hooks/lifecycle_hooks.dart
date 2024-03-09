import 'package:meta/meta.dart';

import '../../melos.dart';

/// Scripts to be executed before/after a melos command.
@immutable
class LifecycleHooks {
  const LifecycleHooks({this.pre, this.post});

  factory LifecycleHooks.fromYaml(
    Map<Object?, Object?> yaml, {
    required String workspacePath,
  }) {
    return LifecycleHooks(
      pre: Script.fromName('pre', yaml, workspacePath),
      post: Script.fromName('post', yaml, workspacePath),
    );
  }

  static const LifecycleHooks empty = LifecycleHooks();

  /// A script to execute before the melos command starts.
  final Script? pre;

  /// A script to execute before the melos command completed.
  final Script? post;

  Map<String, Object?> toJson() {
    return {
      'pre': pre?.toJson(),
      'post': post?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is LifecycleHooks &&
      runtimeType == other.runtimeType &&
      other.pre == pre &&
      other.post == post;

  @override
  int get hashCode => runtimeType.hashCode ^ pre.hashCode ^ post.hashCode;

  @override
  String toString() {
    return '''
LifecycleHooks(
  pre: $pre,
  post: $post,
)
''';
  }
}
