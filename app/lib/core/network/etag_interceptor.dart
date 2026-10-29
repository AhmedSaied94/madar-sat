import 'package:dio/dio.dart';

/// Remembers one ETag per URL in memory and revalidates with `If-None-Match`
/// (constitution VI). On D1 it only stores and sends; the stale-while-revalidate
/// repository arrives on D2.
class EtagInterceptor extends Interceptor {
  final Map<String, _CacheEntry> _cache = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final cached = _cache[options.uri.toString()];
    if (cached != null) {
      options.headers['If-None-Match'] = cached.etag;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final etag = response.headers.value('etag');
    final uri = response.requestOptions.uri.toString();
    if (etag != null) {
      _cache[uri] = _CacheEntry(etag: etag, body: response.data);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    final uri = err.requestOptions.uri.toString();
    final cached = _cache[uri];
    if (status == 304 && cached != null) {
      handler.resolve(
        Response<dynamic>(
          requestOptions: err.requestOptions,
          statusCode: 304,
          data: cached.body,
          headers: Headers.fromMap({
            'etag': [cached.etag],
          }),
        ),
      );
      return;
    }
    handler.next(err);
  }
}

class _CacheEntry {
  const _CacheEntry({required this.etag, required this.body});

  final String etag;
  final Object? body;
}
