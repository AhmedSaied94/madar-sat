import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// A Dio adapter that trusts the dev Caddy root at [path] on top of the platform's own
/// roots (M-T045-1). Debug native builds only: [devCaPath] returns null for release and
/// web builds, so this file's work never reaches a published app.
///
/// A missing or unreadable file fails with a message that names the dart-define, because a
/// silent fallback would look like a server outage (`ApiFailure` with no status).
HttpClientAdapter? createDevCaAdapter(String path) {
  final context = SecurityContext(withTrustedRoots: true);
  try {
    context.setTrustedCertificates(path);
  } on FileSystemException catch (error) {
    throw StateError(
      'DEV_CA_PATH could not be read at $path (${error.message}). Copy the dev Caddy root '
      '(docs/runbooks/local-dev.md, "The app\'s dev flavor") or drop the dart-define.',
    );
  } on TlsException catch (error) {
    throw StateError(
      'DEV_CA_PATH at $path is not a PEM certificate (${error.message}). Copy the dev Caddy '
      'root with `docker compose -f infra/compose/dev.yml cp '
      'caddy:/data/caddy/pki/authorities/local/root.crt ./root.crt`.',
    );
  }
  return IOHttpClientAdapter(createHttpClient: () => HttpClient(context: context));
}
