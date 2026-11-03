/// Where the page's release files live (research R11, `contracts/web-release.md`).
///
/// A release build stages Flutter's output as `<mirror or ''>/r/<hash>/…` and stamps the
/// hash into `flutter_bootstrap.js`, which publishes it to Dart as
/// `window.MADAR_RELEASE = {base, hash}`. drift needs it: `sqlite3.wasm` ships inside the
/// release folder (about 1 MB, so it comes from the mirror, not from Firebase on every
/// first load), and the app can only find it through that stamped value.
///
/// Off the web, and in tests, the page has no release: the plain `sqlite3.wasm` of
/// `web/` is right (see `app/CLAUDE.md`, "Drift schema").
library;

import 'release_assets_stub.dart'
    if (dart.library.js_interop) 'release_assets_web.dart' as platform;

/// What `flutter_bootstrap.js` stamped on this page, or null when there is none.
({String base, String hash})? madarRelease() => platform.readMadarRelease();

/// The URL drift opens `sqlite3.wasm` from: `<base>/r/<hash>/sqlite3.wasm` for a staged
/// release, and `sqlite3.wasm` when [hash] is missing (debug, tests, an older shell).
Uri sqlite3WasmUri({String? base, String? hash}) {
  if (hash == null || hash.isEmpty) return Uri.parse('sqlite3.wasm');
  final prefix = base == null || base.isEmpty ? '' : base.replaceFirst(RegExp(r'/+$'), '');
  return Uri.parse('$prefix/r/$hash/sqlite3.wasm');
}
