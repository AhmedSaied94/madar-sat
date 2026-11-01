import 'package:dio/dio.dart';

/// Adds the device's own token to every public API call (research R1, R2, R11, R27).
///
/// The header is what makes `/v1`'s rate limits count one phone at a time: phones behind
/// one carrier IP would otherwise share a bucket. It goes on **every** `/v1` request once a
/// token exists, and on nothing else — not the media host, not another host, not a path
/// outside `/v1`.
class DeviceAuthInterceptor extends Interceptor {
  DeviceAuthInterceptor({required this.token, required String baseUrl})
      : _apiHost = Uri.tryParse(baseUrl)?.host ?? '';

  /// Read at request time, so a token that arrives after the Dio was built still applies.
  final String? Function() token;

  final String _apiHost;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final value = token();
    final uri = options.uri;
    final isPublicApi = options.path.isNotEmpty;
    final isApiHost = _apiHost.isNotEmpty && uri.host == _apiHost;
    if (value != null && value.isNotEmpty && isPublicApi && isApiHost) {
      options.headers['Authorization'] = 'Device $value';
    }
    handler.next(options);
  }
}
