import 'package:dio/dio.dart';

/// Adds the device's own token to every `/v1` call of the API (research R1, R2, R11, R27).
///
/// The header is what makes `/v1`'s rate limits count one phone at a time: phones behind
/// one carrier IP would otherwise share a bucket. It goes on **every** `/v1` request once a
/// token exists, and on nothing else — not the media host, not another host, not `/healthz`,
/// not a path outside `/v1`, and never over a different scheme or port (M-R1-9).
class DeviceAuthInterceptor extends Interceptor {
  DeviceAuthInterceptor({required this.token, required String baseUrl})
      : _apiOrigin = _originOf(baseUrl);

  /// Read at request time, so a token that arrives after the Dio was built still applies.
  final String? Function() token;

  /// Scheme, host and port of the API, without its path: `https://api.test:443`.
  final Uri? _apiOrigin;

  static Uri? _originOf(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) return null;
    return Uri(scheme: uri.scheme, host: uri.host, port: uri.port);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final value = token();
    final uri = options.uri;
    final origin = _apiOrigin;
    final isSameOrigin = origin != null &&
        uri.scheme == origin.scheme &&
        uri.host == origin.host &&
        uri.port == origin.port;
    // The path segments are compared one by one: `v1` is the API's version segment.
    final segments = uri.pathSegments;
    final isPublicApi = segments.isNotEmpty && segments.first == 'v1';
    if (value != null && value.isNotEmpty && isSameOrigin && isPublicApi) {
      options.headers['Authorization'] = 'Device $value';
    }
    handler.next(options);
  }
}
