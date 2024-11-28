import 'package:pubspec_parse/pubspec_parse.dart';

extension VersionConstraintExtension on Dependency {
  Object toJson() => toString();
}
