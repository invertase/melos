import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

@visibleForTesting
http.Client internalHttpClient = http.Client();

http.Client get httpClient => internalHttpClient;
