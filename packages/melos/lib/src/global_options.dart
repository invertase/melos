import 'package:meta/meta.dart';

/// Global options that apply to all Melos commands.
@immutable
class GlobalOptions {
  const GlobalOptions({
    this.verbose = false,
    this.sdkPath,
    this.noPub = false,
  });

  /// Whether to print verbose output.
  final bool verbose;

  /// Path to the Dart/Flutter SDK that should be used.
  final String? sdkPath;

  /// Whether to skip calling pub get before running commands.
  final bool noPub;

  Map<String, Object?> toJson() {
    return {
      'verbose': verbose,
      'sdkPath': sdkPath,
      'noPub': noPub,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlobalOptions &&
          other.runtimeType == runtimeType &&
          other.verbose == verbose &&
          other.sdkPath == sdkPath &&
          other.noPub == noPub;

  @override
  int get hashCode => verbose.hashCode ^ sdkPath.hashCode ^ noPub.hashCode;

  @override
  String toString() {
    return '''
GlobalOptions(
  verbose: $verbose,
  sdkPath: $sdkPath,
  noPub: $noPub,
)''';
  }
}
