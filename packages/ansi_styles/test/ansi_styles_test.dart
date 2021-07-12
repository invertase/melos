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

import 'package:ansi_styles/ansi_styles.dart';
import 'package:test/test.dart';

String getOutput(String input, int open, int close) {
  return '\u001B[${open}m$input\u001B[${close}m';
}

void main() {
  setUpAll(() {
    ansiStylesDisabled = false;
  });

  group('Colors', () {
    test('black', () {
      expect(AnsiStyles.black('foo'), equals(getOutput('foo', 30, 39)));
    });
    test('red', () {
      expect(AnsiStyles.red('foo'), equals(getOutput('foo', 31, 39)));
    });
    test('green', () {
      expect(AnsiStyles.green('foo'), equals(getOutput('foo', 32, 39)));
    });
    test('yellow', () {
      expect(AnsiStyles.yellow('foo'), equals(getOutput('foo', 33, 39)));
    });
    test('blue', () {
      expect(AnsiStyles.blue('foo'), equals(getOutput('foo', 34, 39)));
    });
    test('magenta', () {
      expect(AnsiStyles.magenta('foo'), equals(getOutput('foo', 35, 39)));
    });
    test('cyan', () {
      expect(AnsiStyles.cyan('foo'), equals(getOutput('foo', 36, 39)));
    });
    test('white', () {
      expect(AnsiStyles.white('foo'), equals(getOutput('foo', 37, 39)));
    });
    test('blackBright', () {
      expect(AnsiStyles.blackBright('foo'), equals(getOutput('foo', 90, 39)));
      expect(AnsiStyles.grey('foo'), equals(getOutput('foo', 90, 39)));
      expect(AnsiStyles.gray('foo'), equals(getOutput('foo', 90, 39)));
    });
    test('redBright', () {
      expect(AnsiStyles.redBright('foo'), equals(getOutput('foo', 91, 39)));
    });
    test('greenBright', () {
      expect(AnsiStyles.greenBright('foo'), equals(getOutput('foo', 92, 39)));
    });
    test('yellowBright', () {
      expect(AnsiStyles.yellowBright('foo'), equals(getOutput('foo', 93, 39)));
    });
    test('blueBright', () {
      expect(AnsiStyles.blueBright('foo'), equals(getOutput('foo', 94, 39)));
    });
    test('magentaBright', () {
      expect(AnsiStyles.magentaBright('foo'), equals(getOutput('foo', 95, 39)));
    });

    test('whiteBright', () {
      expect(AnsiStyles.whiteBright('foo'), equals(getOutput('foo', 97, 39)));
    });

    test('bgBlack', () {
      expect(AnsiStyles.bgBlack('foo'), equals(getOutput('foo', 40, 49)));
    });
    test('bgRed', () {
      expect(AnsiStyles.bgRed('foo'), equals(getOutput('foo', 41, 49)));
    });
    test('bgGreen', () {
      expect(AnsiStyles.bgGreen('foo'), equals(getOutput('foo', 42, 49)));
    });
    test('bgYellow', () {
      expect(AnsiStyles.bgYellow('foo'), equals(getOutput('foo', 43, 49)));
    });
    test('bgBlue', () {
      expect(AnsiStyles.bgBlue('foo'), equals(getOutput('foo', 44, 49)));
    });
    test('bgMagenta', () {
      expect(AnsiStyles.bgMagenta('foo'), equals(getOutput('foo', 45, 49)));
    });
    test('bgCyan', () {
      expect(AnsiStyles.bgCyan('foo'), equals(getOutput('foo', 46, 49)));
    });
    test('bgWhite', () {
      expect(AnsiStyles.bgWhite('foo'), equals(getOutput('foo', 47, 49)));
    });
    test('bgBlackBright', () {
      expect(
        AnsiStyles.bgBlackBright('foo'),
        equals(getOutput('foo', 100, 49)),
      );
      expect(AnsiStyles.bgGrey('foo'), equals(getOutput('foo', 100, 49)));
      expect(AnsiStyles.bgGray('foo'), equals(getOutput('foo', 100, 49)));
    });
    test('bgRedBright', () {
      expect(AnsiStyles.bgRedBright('foo'), equals(getOutput('foo', 101, 49)));
    });
    test('bgGreenBright', () {
      expect(
        AnsiStyles.bgGreenBright('foo'),
        equals(getOutput('foo', 102, 49)),
      );
    });
    test('bgYellowBright', () {
      expect(
        AnsiStyles.bgYellowBright('foo'),
        equals(getOutput('foo', 103, 49)),
      );
    });
    test('bgBlueBright', () {
      expect(AnsiStyles.bgBlueBright('foo'), equals(getOutput('foo', 104, 49)));
    });
    test('bgMagentaBright', () {
      expect(
        AnsiStyles.bgMagentaBright('foo'),
        equals(getOutput('foo', 105, 49)),
      );
    });
    test('bgCyanBright', () {
      expect(AnsiStyles.bgCyanBright('foo'), equals(getOutput('foo', 106, 49)));
    });
    test('bgWhiteBright', () {
      expect(
        AnsiStyles.bgWhiteBright('foo'),
        equals(getOutput('foo', 107, 49)),
      );
    });
  });

  group('Modifiers', () {
    test('reset', () {
      expect(AnsiStyles.reset('foo'), equals(getOutput('foo', 0, 0)));
    });
    test('bold', () {
      expect(AnsiStyles.bold('foo'), equals(getOutput('foo', 1, 22)));
    });
    test('dim', () {
      expect(AnsiStyles.dim('foo'), equals(getOutput('foo', 2, 22)));
    });
    test('italic', () {
      expect(AnsiStyles.italic('foo'), equals(getOutput('foo', 3, 23)));
    });
    test('underline', () {
      expect(AnsiStyles.underline('foo'), equals(getOutput('foo', 4, 24)));
    });
    test('inverse', () {
      expect(AnsiStyles.inverse('foo'), equals(getOutput('foo', 7, 27)));
    });
    test('inverse', () {
      expect(AnsiStyles.hidden('foo'), equals(getOutput('foo', 8, 28)));
    });
    test('strikethrough', () {
      expect(AnsiStyles.strikethrough('foo'), equals(getOutput('foo', 9, 29)));
    });
  });

  test('bullet', () {
    expect(
      AnsiStyles.bgWhiteBright.bullet,
      equals(getOutput(AnsiStyles.bullet, 107, 49)),
    );
  });
  test('strip', () {
    expect(AnsiStyles.bgWhiteBright.underline.strip('foo'), equals('foo'));
  });

  test('chaining', () {
    expect(
      AnsiStyles.red.underline('foo'),
      equals(getOutput(getOutput('foo', 31, 39), 4, 24)),
    );
  });
}
