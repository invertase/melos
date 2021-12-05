/// A base class for all melos exceptions.
abstract class MelosException implements Exception {}

class CancelledException implements MelosException {
  @override
  String toString() {
    return 'CancelledException: Operation was canceled.';
  }
}

class RestrictedBranchException implements MelosException {
  RestrictedBranchException(this.allowedBranch, this.currentBranch);
  final String allowedBranch;
  final String currentBranch;
  @override
  String toString() {
    return 'RestrictedBranchException: This command is configured in melos.yaml to only be '
        'allowed to run on the "$allowedBranch" but the current branch is "$currentBranch".';
  }
}
