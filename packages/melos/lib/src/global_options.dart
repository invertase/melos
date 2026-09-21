import 'package:meta/meta.dart';

/// Global options that apply to all Melos commands.
@immutable
class GlobalOptions {
  const GlobalOptions({
    this.verbose = false,
    this.quiet = false,
    this.sdkPath,
  });

  /// Whether to print verbose output.
  final bool verbose;

  /// Whether to only print warnings, errors and the output of failed commands.
  final bool quiet;

  /// Path to the Dart/Flutter SDK that should be used.
  final String? sdkPath;

  Map<String, Object?> toJson() {
    return {
      'verbose': verbose,
      'quiet': quiet,
      'sdkPath': sdkPath,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlobalOptions &&
          other.runtimeType == runtimeType &&
          other.verbose == verbose &&
          other.quiet == quiet &&
          other.sdkPath == sdkPath;

  @override
  int get hashCode => Object.hashAll([runtimeType, verbose, quiet, sdkPath]);

  @override
  String toString() {
    return '''
GlobalOptions(
  verbose: $verbose,
  quiet: $quiet,
  sdkPath: $sdkPath,
)''';
  }
}
