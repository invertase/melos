import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

@visibleForTesting
http.Client innerHttpClient = http.Client();

http.Client get globalHttpClient => innerHttpClient;
