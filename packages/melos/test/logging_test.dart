import 'package:melos/melos.dart';
import 'package:melos/src/command_runner/base.dart';
import 'package:test/test.dart';

import 'matchers.dart';
import 'utils.dart';

void main() {
  group('MelosLogger', () {
    group('quiet', () {
      late TestLogger testLogger;
      late MelosLogger logger;

      setUp(() {
        testLogger = TestLogger();
        logger = MelosLogger(testLogger, isQuiet: true);
      });

      test('suppresses informational messages', () {
        logger
          ..command('melos exec')
          ..log('log')
          ..logWithoutNewLine('log without new line')
          ..success('success')
          ..hint('hint')
          ..newLine()
          ..horizontalLine()
          ..child('child').child('grandchild');
        logger.progress('progress').finish(message: 'done');

        expect(testLogger.output, isEmpty);
      });

      test('prints warnings, errors and results', () {
        logger
          ..warning('warning')
          ..error('error')
          ..stdout('result')
          ..child('child error', stderr: true);

        expect(
          testLogger.output,
          ignoringAnsii('''
WARNING: warning
e-ERROR: error
result
e-  └> child error
'''),
        );
      });

      test('prints the groups that were not discarded', () async {
        logger
          ..log('a line', group: 'a')
          ..log('b line', group: 'b')
          ..error('b error', group: 'b', label: false)
          ..discardGroup('a');

        await logger.flushGroupBufferIfNeed();

        expect(
          testLogger.output,
          ignoringAnsii('''
b line
e-b error
'''),
        );
      });

      test('essential prints informational messages', () {
        logger.essential
          ..command('melos exec')
          ..child('child');

        expect(
          testLogger.output,
          ignoringAnsii('''
melos exec
  └> child
'''),
        );
      });
    });

    test('essential is the logger itself when it is not quiet', () {
      final logger = MelosLogger(TestLogger());

      expect(logger.essential, same(logger));
    });
  });

  group('resolveQuiet', () {
    test('defaults to the configured value', () {
      expect(
        resolveQuiet(configQuiet: true, envQuiet: null, commandQuiet: null),
        isTrue,
      );
      expect(
        resolveQuiet(configQuiet: false, envQuiet: null, commandQuiet: null),
        isFalse,
      );
    });

    test('the environment variable overrides the configured value', () {
      expect(
        resolveQuiet(configQuiet: false, envQuiet: 'true', commandQuiet: null),
        isTrue,
      );
      expect(
        resolveQuiet(configQuiet: true, envQuiet: 'false', commandQuiet: null),
        isFalse,
      );
    });

    test('ignores an environment variable with an unknown value', () {
      expect(
        resolveQuiet(configQuiet: true, envQuiet: 'maybe', commandQuiet: null),
        isTrue,
      );
    });

    test('the command line option overrides everything else', () {
      expect(
        resolveQuiet(configQuiet: true, envQuiet: 'true', commandQuiet: false),
        isFalse,
      );
      expect(
        resolveQuiet(configQuiet: false, envQuiet: 'false', commandQuiet: true),
        isTrue,
      );
    });
  });
}
