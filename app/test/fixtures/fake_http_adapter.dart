import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A scripted Dio adapter: each request takes the next queued response, and every request is
/// recorded so a test can assert on its headers and query.
///
/// Queue with [enqueue]; once the queue is empty a further request fails loudly, so a
/// repository that sends an unexpected request cannot pass by accident.
class FakeHttpAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<FutureOr<ResponseBody> Function(RequestOptions options)> _script = [];

  /// The `If-None-Match` of request [index], lower-cased header lookup.
  String? ifNoneMatch(int index) =>
      requests[index].headers.entries
          .where((e) => e.key.toLowerCase() == 'if-none-match')
          .map((e) => '${e.value}')
          .firstOrNull;

  void enqueue(FutureOr<ResponseBody> Function(RequestOptions options) respond) =>
      _script.add(respond);

  /// A `200` with the API envelope around [data] and an optional `ETag`.
  void enqueueData(Object? data, {String? etag, int status = 200}) =>
      enqueue((_) => envelope(data, etag: etag, status: status));

  /// A `304 Not Modified`, as the server answers a matching `If-None-Match`.
  void enqueueNotModified({String? etag}) => enqueue((_) => notModified(etag: etag));

  /// A transport failure: no connection.
  void enqueueOffline() => enqueue(
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'offline',
        ),
      );

  /// A non-2xx API answer with the envelope's `error.code`.
  void enqueueError(String code, {int status = 500}) => enqueue(
        (_) => ResponseBody.fromString(
          jsonEncode({
            'success': false,
            'data': null,
            'error': {'code': code, 'message': 'for logs only'},
            'meta': <String, Object?>{},
          }),
          status,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );

  static ResponseBody envelope(Object? data, {String? etag, int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode({
          'success': true,
          'data': data,
          'error': null,
          'meta': <String, Object?>{},
        }),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
          if (etag != null) 'etag': [etag],
        },
      );

  static ResponseBody notModified({String? etag}) => ResponseBody.fromString(
        '',
        304,
        headers: {
          if (etag != null) 'etag': [etag],
        },
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_script.isEmpty) {
      throw StateError('FakeHttpAdapter: unexpected request ${options.method} ${options.uri}');
    }
    return _script.removeAt(0)(options);
  }

  @override
  void close({bool force = false}) {}
}

/// A Dio wired to [adapter] for repository tests.
Dio fakeDio(FakeHttpAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = adapter;
