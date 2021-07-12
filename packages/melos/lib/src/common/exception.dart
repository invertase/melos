/// A base class for all melos exceptions.
abstract class MelosException implements Exception {}

class CancelledException implements MelosException {
  @override
  String toString() {
    return 'CancelledException: Operation was canceled.';
  }
}
