import 'dart:io';

import 'package:melos/melos.dart';
import 'package:melos/src/common/git.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('Git', () {
    test('gitGetCurrentBranchName', () async {
      final branchName = await gitGetCurrentBranchName(
        workingDirectory: Directory.current.path,
        logger: TestLogger().toMelosLogger(),
      );
      expect(branchName, isA<String>());
      expect(branchName, isNotEmpty);
    });

    test('gitTagExists', () async {
      const aTagThatExists = 'melos-v0.4.11';
      const aTagThatDoesNotExist = 'not-melos-v0.4.11';
      final workingDirectory = Directory.current.path;

      expect(
        await gitTagExists(
          aTagThatExists,
          workingDirectory: workingDirectory,
          logger: TestLogger().toMelosLogger(),
        ),
        isTrue,
      );
      expect(
        await gitTagExists(
          aTagThatDoesNotExist,
          workingDirectory: workingDirectory,
          logger: TestLogger().toMelosLogger(),
        ),
        isFalse,
      );
    });

    test('gitExecuteCommand throws a ProcessException on error', () async {
      expect(
        () => gitExecuteCommand(
          arguments: ['foo', 'bar'],
          workingDirectory: Directory.current.path,
          logger: TestLogger().toMelosLogger(),
        ),
        throwsA(isA<ProcessException>()),
      );
    });
  });
}
