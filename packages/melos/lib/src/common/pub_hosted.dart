import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'http.dart';
import 'platform.dart';
import 'pub_credential.dart';
import 'pub_hosted_package.dart';

/// The URL where we can find a package server.
///
/// The default is `pub.dev`, but it can be overridden using the
/// `PUB_HOSTED_URL` environment variable.
/// https://dart.dev/tools/pub/environment-variables
Uri get defaultPubUrl => Uri.parse(
      currentPlatform.environment['PUB_HOSTED_URL'] ?? 'https://pub.dev',
    );

class PubHostedClient extends http.BaseClient {
  @visibleForTesting
  PubHostedClient(this.pubHosted, this._inner, this._credentialStore);

  factory PubHostedClient.fromUri({required Uri? pubHosted}) {
    final store = pubCredentialStore;
    final innerClient = httpClient;
    final uri = normalizeHostedUrl(pubHosted ?? defaultPubUrl);

    return PubHostedClient(uri, innerClient, store);
  }

  final http.Client _inner;

  final PubCredentialStore _credentialStore;

  final Uri pubHosted;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final credential = _credentialStore.findCredential(pubHosted);

    if (credential != null) {
      final authToken = credential.getAuthHeader();
      if (authToken != null) {
        request.headers[HttpHeaders.authorizationHeader] = authToken;
      }
    }

    return _inner.send(request);
  }

  Future<PubHostedPackage?> fetchPackage(String name) async {
    final url = pubHosted.resolve('api/packages/$name');
    final response = await get(url);

    if (response.statusCode == 404) {
      // The package was never published
      return null;
    } else if (response.statusCode != 200) {
      throw Exception(
        'Error reading pub.dev registry for package "$name" '
        '(HTTP Status ${response.statusCode}), response: ${response.body}',
      );
    }

    final data = json.decode(response.body) as Map<String, Object?>;
    return PubHostedPackage.fromJson(data);
  }

  @override
  void close() => _inner.close();
}

Uri normalizeHostedUrl(Uri uri) {
  var u = uri;

  if (!u.hasScheme || (u.scheme != 'http' && u.scheme != 'https')) {
    throw FormatException('url scheme must be https:// or http://', uri);
  }
  if (!u.hasAuthority || u.host == '') {
    throw FormatException('url must have a hostname', uri);
  }
  if (u.userInfo != '') {
    throw FormatException('user-info is not supported in url', uri);
  }
  if (u.hasQuery) {
    throw FormatException('querystring is not supported in url', uri);
  }
  if (u.hasFragment) {
    throw FormatException('fragment is not supported in url', uri);
  }
  u = u.normalizePath();
  // If we have a path of only `/`
  if (u.path == '/') {
    u = u.replace(path: '');
  }
  // If there is a path, and it doesn't end in a slash we normalize to slash
  if (u.path.isNotEmpty && !u.path.endsWith('/')) {
    u = u.replace(path: '${u.path}/');
  }

  return u;
}
