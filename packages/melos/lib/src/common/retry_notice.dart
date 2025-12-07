class RetryNotice {
  const RetryNotice({
    required this.url,
    required this.method,
    required this.attempt,
    required this.maxAttempts,
    required this.delay,
    required this.reason,
    this.statusCode,
    this.error,
  });

  /// URL being requested.
  final Uri url;

  /// HTTP method being invoked.
  final String method;

  /// 1-based attempt number that will be executed after [delay].
  final int attempt;

  /// Maximum attempts before giving up.
  final int maxAttempts;

  /// Delay before retrying the request.
  final Duration delay;

  /// Human-friendly description of why the retry is happening.
  final String reason;

  /// HTTP status code when a response triggered the retry.
  final int? statusCode;

  /// Exception that triggered the retry, if any.
  final Object? error;

  bool get isLastAttempt => attempt >= maxAttempts;
}
