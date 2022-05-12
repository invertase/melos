import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

@visibleForTesting
http.Client? testClient;

Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
    testClient?.get(url, headers: headers) ?? http.get(url, headers: headers);
