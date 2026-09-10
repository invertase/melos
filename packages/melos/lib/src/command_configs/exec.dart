import 'package:meta/meta.dart';

import '../common/validation.dart';

/// Configurations for `melos exec`.
@immutable
class ExecCommandConfigs {
  const ExecCommandConfigs({
    this.concurrency,
    this.failFast,
    this.orderDependents,
    this.groupLogs,
  });

  factory ExecCommandConfigs.fromYaml(Map<Object?, Object?> yaml) {
    final concurrency = assertKeyIsA<int?>(
      key: 'concurrency',
      map: yaml,
      path: 'command/exec',
    );

    final failFast = assertKeyIsA<bool?>(
      key: 'failFast',
      map: yaml,
      path: 'command/exec',
    );

    final orderDependents = assertKeyIsA<bool?>(
      key: 'orderDependents',
      map: yaml,
      path: 'command/exec',
    );

    final groupLogs = assertKeyIsA<bool?>(
      key: 'groupLogs',
      map: yaml,
      path: 'command/exec',
    );

    return ExecCommandConfigs(
      concurrency: concurrency,
      failFast: failFast,
      orderDependents: orderDependents,
      groupLogs: groupLogs,
    );
  }

  static const ExecCommandConfigs empty = ExecCommandConfigs();

  /// The number of packages to run the command in concurrently.
  ///
  /// The default is the number of processors on the machine.
  final int? concurrency;

  /// Whether to stop executing the command in further packages as soon as it
  /// fails in one package.
  ///
  /// The default is `false`.
  final bool? failFast;

  /// Whether to order the execution of the command based on the dependency
  /// graph of the packages.
  ///
  /// The default is `false`.
  final bool? orderDependents;

  /// Whether the output of each package is buffered and printed grouped per
  /// package, instead of being streamed and interleaved.
  ///
  /// The default is `false`.
  final bool? groupLogs;

  Map<String, Object?> toJson() {
    return {
      if (concurrency != null) 'concurrency': concurrency,
      if (failFast != null) 'failFast': failFast,
      if (orderDependents != null) 'orderDependents': orderDependents,
      if (groupLogs != null) 'groupLogs': groupLogs,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ExecCommandConfigs &&
      other.runtimeType == runtimeType &&
      other.concurrency == concurrency &&
      other.failFast == failFast &&
      other.orderDependents == orderDependents &&
      other.groupLogs == groupLogs;

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    concurrency,
    failFast,
    orderDependents,
    groupLogs,
  ]);

  @override
  String toString() {
    return '''
ExecCommandConfigs(
  concurrency: $concurrency,
  failFast: $failFast,
  orderDependents: $orderDependents,
  groupLogs: $groupLogs,
)''';
  }
}
