import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/etag_interceptor.dart';

/// Answers each request from a script and records the request headers it saw.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._script);

  final List<({int status, String body, String? etag})> _script;
  final List<Map<String, dynamic>> seenHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seenHeaders.add(Map<String, dynamic>.of(options.headers));
    final step = _script.removeAt(0);
    return ResponseBody.fromString(
      step.body,
      step.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (step.etag != null) 'etag': [step.etag!],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_ScriptedAdapter adapter) => Dio(BaseOptions(baseUrl: 'https://api.test'))
  ..httpClientAdapter = adapter
  ..interceptors.add(EtagInterceptor());

String _json(Object body) => jsonEncode(body);

void main() {
  test('sends If-None-Match on the second request for the same URL', () async {
    final adapter = _ScriptedAdapter([
      (status: 200, body: _json({'n': 1}), etag: 'W/"abc"'),
      (status: 200, body: _json({'n': 2}), etag: 'W/"def"'),
    ]);
    final dio = _dio(adapter);

    await dio.get<dynamic>('/v1/matches');
    await dio.get<dynamic>('/v1/matches');

    expect(adapter.seenHeaders[0].containsKey('If-None-Match'), isFalse);
    expect(adapter.seenHeaders[1]['If-None-Match'], 'W/"abc"');
  });

  test('turns a 304 into the cached body and keeps the ETag', () async {
    final adapter = _ScriptedAdapter([
      (status: 200, body: _json({'n': 1}), etag: 'W/"abc"'),
      (status: 304, body: '', etag: 'W/"abc"'),
    ]);
    final dio = _dio(adapter);

    await dio.get<dynamic>('/v1/matches');
    final revalidated = await dio.get<dynamic>('/v1/matches');

    expect(revalidated.statusCode, 304);
    expect(revalidated.data, {'n': 1});
    expect(revalidated.headers.value('etag'), 'W/"abc"');
  });

  test('a 200 after a stored ETag replaces both the ETag and the body', () async {
    final adapter = _ScriptedAdapter([
      (status: 200, body: _json({'n': 1}), etag: 'W/"abc"'),
      (status: 200, body: _json({'n': 2}), etag: 'W/"def"'),
      (status: 304, body: '', etag: 'W/"def"'),
    ]);
    final dio = _dio(adapter);

    await dio.get<dynamic>('/v1/matches');
    await dio.get<dynamic>('/v1/matches');
    final revalidated = await dio.get<dynamic>('/v1/matches');

    expect(adapter.seenHeaders[2]['If-None-Match'], 'W/"def"');
    expect(revalidated.data, {'n': 2});
  });

  test('does not share ETags between URLs, including different query strings', () async {
    final adapter = _ScriptedAdapter([
      (status: 200, body: _json({'day': 1}), etag: 'W/"one"'),
      (status: 200, body: _json({'day': 2}), etag: 'W/"two"'),
    ]);
    final dio = _dio(adapter);

    await dio.get<dynamic>('/v1/matches', queryParameters: {'from': 'a'});
    await dio.get<dynamic>('/v1/matches', queryParameters: {'from': 'b'});

    expect(adapter.seenHeaders[1].containsKey('If-None-Match'), isFalse);
  });

  test('a response without an ETag stores nothing', () async {
    final adapter = _ScriptedAdapter([
      (status: 200, body: _json({'n': 1}), etag: null),
      (status: 200, body: _json({'n': 2}), etag: null),
    ]);
    final dio = _dio(adapter);

    await dio.get<dynamic>('/v1/matches');
    await dio.get<dynamic>('/v1/matches');

    expect(adapter.seenHeaders[1].containsKey('If-None-Match'), isFalse);
  });

  test('a 304 with nothing cached surfaces as an error instead of empty data', () async {
    final adapter = _ScriptedAdapter([
      (status: 304, body: '', etag: 'W/"abc"'),
    ]);
    final dio = _dio(adapter);

    await expectLater(
      dio.get<dynamic>('/v1/matches'),
      throwsA(
        isA<DioException>().having((e) => e.response?.statusCode, 'status', 304),
      ),
    );
  });

  test('a request that opts out neither sends nor stores an ETag (the SWR repository)', () async {
    final adapter = _ScriptedAdapter([
      (status: 200, body: _json({'n': 1}), etag: 'W/"abc"'),
      (status: 200, body: _json({'n': 2}), etag: 'W/"def"'),
      (status: 200, body: _json({'n': 3}), etag: 'W/"ghi"'),
    ]);
    final dio = _dio(adapter);
    final optOut = Options(extra: {EtagInterceptor.bypassKey: true});

    await dio.get<dynamic>('/v1/matches', options: optOut);
    await dio.get<dynamic>('/v1/matches', options: optOut);
    // The opted-out calls stored nothing, so a normal call has no ETag to send either.
    await dio.get<dynamic>('/v1/matches');

    expect(adapter.seenHeaders[1].containsKey('If-None-Match'), isFalse);
    expect(adapter.seenHeaders[2].containsKey('If-None-Match'), isFalse);
  });

  test('an opted-out 304 is left as an error for the caller to read', () async {
    final adapter = _ScriptedAdapter([
      (status: 200, body: _json({'n': 1}), etag: 'W/"abc"'),
      (status: 304, body: '', etag: 'W/"abc"'),
    ]);
    final dio = _dio(adapter);

    await dio.get<dynamic>('/v1/matches');

    await expectLater(
      dio.get<dynamic>(
        '/v1/matches',
        options: Options(extra: {EtagInterceptor.bypassKey: true}),
      ),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 304)),
    );
  });

  test('other errors pass through untouched', () async {
    final adapter = _ScriptedAdapter([
      (status: 200, body: _json({'n': 1}), etag: 'W/"abc"'),
      (status: 503, body: _json({'success': false}), etag: null),
    ]);
    final dio = _dio(adapter);

    await dio.get<dynamic>('/v1/matches');

    await expectLater(
      dio.get<dynamic>('/v1/matches'),
      throwsA(
        isA<DioException>().having((e) => e.response?.statusCode, 'status', 503),
      ),
    );
  });
}
