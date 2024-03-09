import 'package:collection/collection.dart';
import 'package:glob/glob.dart';

class GlobEquality implements Equality<Glob> {
  const GlobEquality();

  @override
  bool equals(Glob e1, Glob e2) =>
      e1.pattern == e2.pattern && e1.context.current == e2.context.current;

  @override
  int hash(Glob e) => e.pattern.hashCode ^ e.context.current.hashCode;

  @override
  bool isValidKey(Object? o) => true;
}
