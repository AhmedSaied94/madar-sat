import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'dev_ca_stub.dart' if (dart.library.io) 'dev_ca_io.dart';

/// The `dev` flavor's TLS root, for a phone or emulator talking to `https://localhost:8443`
/// (M-T045-1, research R14, R16).
///
/// Dio runs on `dart:io` on native builds, so it ignores Android's
/// `network_security_config.xml` and the phone's user certificates: without this, every
/// request against the dev Caddy fails the handshake. A debug native build can therefore
/// name the dev root with `--dart-define=DEV_CA_PATH=<file>`; a release build and any web
/// build ignore it, and the file is never bundled.
///
/// ```bash
/// flutter run -t lib/main_dev.dart --dart-define-from-file=env/dev.json \
///   --dart-define=DEV_CA_PATH="$PWD/root.crt"
/// ```
String? devCaPath({String? raw, bool? releaseMode, bool? isWeb}) => devCaPathFor(
      raw ?? const String.fromEnvironment('DEV_CA_PATH'),
      releaseMode: releaseMode ?? kReleaseMode,
      isWeb: isWeb ?? kIsWeb,
    );

/// The pure rule behind [devCaPath]: only a debug native build keeps the value.
String? devCaPathFor(String raw, {required bool releaseMode, required bool isWeb}) {
  final path = raw.trim();
  if (releaseMode || isWeb || path.isEmpty) return null;
  return path;
}

/// A Dio adapter that trusts the root at [path], or null where the platform has no
/// `dart:io` (the web keeps the browser's own trust store).
HttpClientAdapter? devCaAdapter(String path) => createDevCaAdapter(path);
