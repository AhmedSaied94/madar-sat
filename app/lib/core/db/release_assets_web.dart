import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// The web answer: `window.MADAR_RELEASE`, stamped by `flutter_bootstrap.js` (research
/// R11). Absent on a page whose bootstrap was not stamped, which is why the caller falls
/// back to `sqlite3.wasm`.
({String base, String hash})? readMadarRelease() {
  final value = web.window.getProperty('MADAR_RELEASE'.toJS);
  if (!value.isA<JSObject>()) return null;
  final release = value as JSObject;
  final hash = release.getProperty('hash'.toJS);
  if (!hash.isA<JSString>() || (hash as JSString).toDart.isEmpty) return null;
  final base = release.getProperty('base'.toJS);
  return (
    base: base.isA<JSString>() ? (base as JSString).toDart : '',
    hash: hash.toDart,
  );
}
