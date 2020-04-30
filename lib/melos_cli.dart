library flutterfire_tools;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:melos_cli/src/common/plugin.dart';
import 'package:yaml/yaml.dart' as yaml;
import 'package:yamlicious/yamlicious.dart';

import 'src/common/partials.dart' as partials;
import 'src/common/plugin.dart';
import 'src/common/utils.dart' as utils;

part 'src/commands/workspace.dart';

part 'src/commands/workspace_bootstrap.dart';

part 'src/commands/workspace_launch.dart';

part 'src/commands/workspace_pub.dart';

final commandRunner = CommandRunner(
    "melos", "A CLI to help with plugin development for monorepos.")
  ..addCommand(WorkspaceCommand());

Logger logger = new Logger.standard();
