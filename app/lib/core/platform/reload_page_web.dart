import 'package:web/web.dart' as web;

/// Reloads the page the PWA runs in, which is how a fresh deployment reaches an installed
/// app without a store (research R29).
Future<bool> reloadPage() async {
  web.window.location.reload();
  return true;
}
