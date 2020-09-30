# AnsiStyle

A Dart package for creating ansi styled text within io environments.

## Usage

Import the package:

```dart
import 'package:ansi_styles/ansi_styles.dart';
```

Use the `AnsiStyle` export to create styled text by chaining properties. For example:

```dart
void main() {
  print(AnsiStyles.red.underline('Underlined red text'));
  print(AnsiStyles.inverse.italic.green('Inverted italic green text'));
  print(AnsiStyles.cyan('Cyan text'));
  print(AnsiStyles.bgYellowBright.bold('Bold text with a yellow background'));
  print(AnsiStyles.bold.rgb(255,192,203)('Bold pink text'));
  print(AnsiStyles.strikethrough.bgRgb(255,165,0)('Strikethrough text with an orange background'));
}
```

**Output preview**:

![ansi_styles_preview](https://static.invertase.io/assets/ansi_styles_example.png)

To remove any ansi styling from text, call the `strip()` method:

```dart
String styledText = AnsiStyles.red.underline('Underlined red text');
String cleanText = AnsiStyles.strip(styledText);
```

## License

- See [LICENSE](/LICENSE)

---

<p>
  <img align="left" width="75px" src="https://static.invertase.io/assets/invertase-logo-small.png">
  <p align="left">
    Built and maintained with 💛 by <a href="https://invertase.io">Invertase</a>.
  </p>
  <p align="left">
    <a href="https://invertase.link/discord"><img src="https://img.shields.io/discord/295953187817521152.svg?style=flat-square&colorA=7289da&label=Chat%20on%20Discord" alt="Chat on Discord"></a>
    <a href="https://twitter.com/invertaseio"><img src="https://img.shields.io/twitter/follow/invertaseio.svg?style=flat-square&colorA=1da1f2&colorB=&label=Follow%20on%20Twitter" alt="Follow on Twitter"></a>
  </p>
</p>

---
