import 'package:meta/meta.dart';

import '../../melos.dart';
import 'lifecycle_hooks.dart';

/// [LifecycleHooks] for the `publish` command.
@immutable
class PublishLifecycleHooks extends LifecycleHooks {
  const PublishLifecycleHooks({super.pre, super.post});

  factory PublishLifecycleHooks.fromYaml(
    Map<Object?, Object?> yaml, {
    required String workspacePath,
  }) {
    return PublishLifecycleHooks(
      pre: Script.fromName('pre', yaml, workspacePath),
      post: Script.fromName('post', yaml, workspacePath),
    );
  }

  static const PublishLifecycleHooks empty = PublishLifecycleHooks();

  @override
  bool operator ==(Object other) =>
      other is PublishLifecycleHooks &&
      runtimeType == other.runtimeType &&
      other.pre == pre &&
      other.post == post;

  @override
  int get hashCode => Object.hash(runtimeType, pre, post);

  @override
  String toString() {
    return '''
PublishLifecycleHooks(
  pre: $pre,
  post: $post,
)
''';
  }
}
