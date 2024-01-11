import 'dart:convert';
import 'dart:io';

import 'package:cli_util/cli_util.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

import 'io.dart';
import 'pub_hosted.dart';

const _pubTokenFileName = 'pub-tokens.json';

@visibleForTesting
PubCredentialStore internalPubCredentialStore =
    PubCredentialStore.fromConfigFile();

PubCredentialStore get pubCredentialStore => internalPubCredentialStore;

class PubCredentialStore {
  PubCredentialStore(this.credentials);

  factory PubCredentialStore.fromConfigFile({String? configDir}) {
    configDir ??= applicationConfigHome('dart');
    final tokenFilePath = path.join(configDir, _pubTokenFileName);

    if (!fileExists(tokenFilePath)) {
      return PubCredentialStore([]);
    }

    final content =
        jsonDecode(readTextFile(tokenFilePath)) as Map<String, dynamic>?;

    final hostedCredentials = content?['hosted'] as List<dynamic>? ?? const [];

    final credentials = hostedCredentials
        .cast<Map<String, dynamic>>()
        .map(PubCredential.fromJson)
        .toList();

    return PubCredentialStore(credentials);
  }

  final List<PubCredential> credentials;

  PubCredential? findCredential(Uri hostedUrl) {
    return credentials.firstWhereOrNull(
      (c) => c.url == hostedUrl && c.isValid(),
    );
  }
}

class PubCredential {
  @visibleForTesting
  PubCredential({
    required this.url,
    required this.token,
    this.env,
  });

  factory PubCredential.fromJson(Map<String, dynamic> json) {
    final hostedUrl = json['url'] as String?;

    if (hostedUrl == null) {
      throw const FormatException('Url is not provided for the credential');
    }

    return PubCredential(
      url: normalizeHostedUrl(Uri.parse(hostedUrl)),
      token: json['token'] as String?,
      env: json['env'] as String?,
    );
  }

  /// Server url which this token authenticates.
  final Uri url;

  /// Authentication token value
  final String? token;

  /// Environment variable name that stores token value
  final String? env;

  bool isValid() => (token == null) ^ (env == null);

  String? get _tokenValue {
    final environment = env;
    if (environment != null) {
      final value = Platform.environment[environment];

      if (value == null) {
        throw FormatException(
          'Saved credential for "$url" pub repository requires environment '
          'variable named "$env" but not defined.',
        );
      }

      return value;
    } else {
      return token;
    }
  }

  String? getAuthHeader() {
    if (!isValid()) return null;
    return 'Bearer $_tokenValue';
  }
}
