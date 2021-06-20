/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

import 'dart:io';

import 'package:melos/src/common/git.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('Git', () {
    test('gitGetCurrentBranchName', () async {
      final branchName = await gitGetCurrentBranchName(
        workingDirectory: Directory.current.path,
        logger: TestLogger(),
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
          logger: TestLogger(),
        ),
        isTrue,
      );
      expect(
        await gitTagExists(
          aTagThatDoesNotExist,
          workingDirectory: workingDirectory,
          logger: TestLogger(),
        ),
        isFalse,
      );
    });

    test('gitExecuteCommand throws a ProcessException on error', () async {
      expect(
        () => gitExecuteCommand(
          arguments: ['foo', 'bar'],
          workingDirectory: Directory.current.path,
          logger: TestLogger(),
        ),
        throwsA(isA<ProcessException>()),
      );
    });
  });
}
