/// Reloading the PWA (S0's forced update: «reload» on the web, the store on Android).
library;

import 'reload_page_native.dart' if (dart.library.js_interop) 'reload_page_web.dart' as platform;

/// True when this page actually reloaded; false on a native build, where a reload is not a
/// thing and the caller opens the store instead.
Future<bool> reloadPage() => platform.reloadPage();
