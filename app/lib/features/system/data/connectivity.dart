import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity.g.dart';

/// Whether the last request reached the server (research R29). No new plugin: a request
/// that fails with no response marks the app offline, and the next success marks it online
/// again.
@Riverpod(keepAlive: true)
class ConnectivityStatus extends _$ConnectivityStatus {
  @override
  bool build() => true;

  void markOnline() {
    if (!state) state = true;
  }

  void markOffline() {
    if (state) state = false;
  }
}

/// Feeds [ConnectivityStatus] from every request that goes through the app's Dio.
class ConnectivityInterceptor extends Interceptor {
  ConnectivityInterceptor({required this.onOnline, required this.onOffline});

  final void Function() onOnline;
  final void Function() onOffline;

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    onOnline();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // A `304`, a `4xx` or a `5xx` all reached the server: only a transport failure did not.
    if (err.response == null) {
      onOffline();
    } else {
      onOnline();
    }
    handler.next(err);
  }
}
