import 'dart:io' as io;

bool get supportsAnsiColor => io.stdout.supportsAnsiEscapes;
