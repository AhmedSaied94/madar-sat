import 'package:dio/dio.dart';

/// The web's answer (M-T045-1): the browser owns TLS trust, so a dart-define can never add
/// a root and the app keeps the default adapter.
HttpClientAdapter? createDevCaAdapter(String path) => null;
