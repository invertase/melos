import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

/// Returns a [Glob] configured to work in both production and test
/// environments.
///
/// Workaround for https://github.com/dart-lang/glob/issues/52
Glob createGlob(
  String pattern, {
  p.Context? context,
  bool recursive = false,
  bool? caseSensitive,
  required String currentDirectoryPath,
}) {
  context ??= p.Context(
    style: p.context.style,
    // This ensures that IOOverrides are taken into account when determining the
    // current working directory used by the Glob.
    //
    // See https://github.com/dart-lang/glob/issues/52 for more information.
    current: currentDirectoryPath,
  );
  return Glob(
    pattern,
    context: context,
    recursive: recursive,
    caseSensitive: caseSensitive,
  );
}
