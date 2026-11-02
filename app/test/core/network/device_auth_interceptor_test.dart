import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/device_auth_interceptor.dart';

import '../../fixtures/fake_http_adapter.dart';

/// Where `Authorization: Device` goes and, more importantly, where it does not: every `/v1`
/// call of the API origin once a token exists, and nothing else (research R27, M-R1-9).
void main() {
  late FakeHttpAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = FakeHttpAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://api.madarsat.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        DeviceAuthInterceptor(token: () => 'srv-token', baseUrl: 'https://api.madarsat.test'),
      );
  });

  String? authorization(int index) => adapter.requests[index].headers.entries
      .where((entry) => entry.key.toLowerCase() == 'authorization')
      .map((entry) => '${entry.value}')
      .firstOrNull;

  test('every /v1 request of the API origin carries it', () async {
    adapter.enqueueData(const {'ok': true});
    adapter.enqueueData(const {'ok': true});

    await dio.get<Object?>('/v1/matches');
    await dio.get<Object?>('/v1/devices/me');

    expect(authorization(0), 'Device srv-token');
    expect(authorization(1), 'Device srv-token');
  });

  test('a path outside /v1 gets nothing', () async {
    adapter.enqueueData(const {'ok': true});

    await dio.get<Object?>('/healthz');

    expect(authorization(0), isNull);
  });

  test('a foreign host gets nothing, even with the same path', () async {
    adapter.enqueueData(const {'ok': true});

    await dio.get<Object?>('https://media.madarsat.test/v1/matches');

    expect(authorization(0), isNull, reason: 'the media host must never see the token');
  });

  test('a different port or scheme is a different origin', () async {
    adapter.enqueueData(const {'ok': true});
    adapter.enqueueData(const {'ok': true});

    await dio.get<Object?>('https://api.madarsat.test:8443/v1/matches');
    await dio.get<Object?>('http://api.madarsat.test/v1/matches');

    expect(authorization(0), isNull);
    expect(authorization(1), isNull);
  });

  test('no token yet means no header at all', () async {
    final silent = Dio(BaseOptions(baseUrl: 'https://api.madarsat.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        DeviceAuthInterceptor(token: () => null, baseUrl: 'https://api.madarsat.test'),
      );
    adapter.enqueueData(const {'ok': true});

    await silent.get<Object?>('/v1/matches');

    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });
}
