import 'package:dio/dio.dart';

/// Remembers one ETag per URL in memory and revalidates with `If-None-Match`
/// (constitution VI).
///
/// The stale-while-revalidate repository (`SwrRepository`) keeps its ETags in drift
/// instead, and sets [bypassKey] on its requests so the two never disagree about what the
/// server last sent. Everything else (such as the live poll) still gets this memory cache.
class EtagInterceptor extends Interceptor {
  /// `RequestOptions.extra` key: when true, this interceptor neither sends nor stores.
  static const String bypassKey = 'etag.bypass';

  final Map<String, _CacheEntry> _cache = {};

  static bool _bypassed(RequestOptions options) => options.extra[bypassKey] == true;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final cached = _cache[options.uri.toString()];
    if (cached != null && !_bypassed(options)) {
      options.headers['If-None-Match'] = cached.etag;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final etag = response.headers.value('etag');
    final uri = response.requestOptions.uri.toString();
    if (etag != null && !_bypassed(response.requestOptions)) {
      _cache[uri] = _CacheEntry(etag: etag, body: response.data);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    final uri = err.requestOptions.uri.toString();
    final cached = _cache[uri];
    if (status == 304 && cached != null && !_bypassed(err.requestOptions)) {
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
