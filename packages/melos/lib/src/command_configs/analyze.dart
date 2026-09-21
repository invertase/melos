import 'package:meta/meta.dart';

import '../common/validation.dart';

/// Configurations for `melos analyze`.
@immutable
class AnalyzeCommandConfigs {
  const AnalyzeCommandConfigs({
    this.concurrency,
    this.fatalInfos,
    this.fatalWarnings,
    this.noPub,
  });

  factory AnalyzeCommandConfigs.fromYaml(Map<Object?, Object?> yaml) {
    final concurrency = assertKeyIsA<int?>(
      key: 'concurrency',
      map: yaml,
      path: 'command/analyze',
    );

    final fatalInfos = assertKeyIsA<bool?>(
      key: 'fatalInfos',
      map: yaml,
      path: 'command/analyze',
    );

    final fatalWarnings = assertKeyIsA<bool?>(
      key: 'fatalWarnings',
      map: yaml,
      path: 'command/analyze',
    );

    final noPub = assertKeyIsA<bool?>(
      key: 'noPub',
      map: yaml,
      path: 'command/analyze',
    );

    return AnalyzeCommandConfigs(
      concurrency: concurrency,
      fatalInfos: fatalInfos,
      fatalWarnings: fatalWarnings,
      noPub: noPub,
    );
  }

  static const AnalyzeCommandConfigs empty = AnalyzeCommandConfigs();

  /// The number of packages to analyze concurrently.
  ///
  /// The default is `1`.
  final int? concurrency;

  /// Whether info level issues are treated as fatal errors.
  ///
  /// The default is `true`.
  final bool? fatalInfos;

  /// Whether warnings are treated as fatal errors.
  final bool? fatalWarnings;

  /// Whether `--no-pub` is passed to `flutter analyze`, to skip the implicit
  /// `pub get`. Has no effect on `dart analyze`.
  ///
  /// The default is `false`.
  final bool? noPub;

  Map<String, Object?> toJson() {
    return {
      if (concurrency != null) 'concurrency': concurrency,
      if (fatalInfos != null) 'fatalInfos': fatalInfos,
      if (fatalWarnings != null) 'fatalWarnings': fatalWarnings,
      if (noPub != null) 'noPub': noPub,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is AnalyzeCommandConfigs &&
      other.runtimeType == runtimeType &&
      other.concurrency == concurrency &&
      other.fatalInfos == fatalInfos &&
      other.fatalWarnings == fatalWarnings &&
      other.noPub == noPub;

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    concurrency,
    fatalInfos,
    fatalWarnings,
    noPub,
  ]);

  @override
  String toString() {
    return '''
AnalyzeCommandConfigs(
  concurrency: $concurrency,
  fatalInfos: $fatalInfos,
  fatalWarnings: $fatalWarnings,
  noPub: $noPub,
)''';
  }
}
