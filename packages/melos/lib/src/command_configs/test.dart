import 'package:meta/meta.dart';

import '../common/validation.dart';

/// Configurations for `melos test`.
@immutable
class TestCommandConfigs {
  const TestCommandConfigs({
    this.concurrency,
    this.noPub,
  });

  factory TestCommandConfigs.fromYaml(Map<Object?, Object?> yaml) {
    final concurrency = assertKeyIsA<int?>(
      key: 'concurrency',
      map: yaml,
      path: 'command/test',
    );

    final noPub = assertKeyIsA<bool?>(
      key: 'noPub',
      map: yaml,
      path: 'command/test',
    );

    return TestCommandConfigs(
      concurrency: concurrency,
      noPub: noPub,
    );
  }

  static const TestCommandConfigs empty = TestCommandConfigs();

  /// The number of packages to run tests in concurrently.
  ///
  /// The default is `1`.
  final int? concurrency;

  /// Whether `--no-pub` is passed to `flutter test`, to skip the implicit
  /// `pub get`. Has no effect on `dart test`.
  ///
  /// The default is `false`.
  final bool? noPub;

  Map<String, Object?> toJson() {
    return {
      if (concurrency != null) 'concurrency': concurrency,
      if (noPub != null) 'noPub': noPub,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is TestCommandConfigs &&
      other.runtimeType == runtimeType &&
      other.concurrency == concurrency &&
      other.noPub == noPub;

  @override
  int get hashCode => Object.hashAll([runtimeType, concurrency, noPub]);

  @override
  String toString() {
    return '''
TestCommandConfigs(
  concurrency: $concurrency,
  noPub: $noPub,
)''';
  }
}
