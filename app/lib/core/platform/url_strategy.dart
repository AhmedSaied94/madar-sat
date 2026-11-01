/// Which part of the address Flutter web reads its route from (M-R1-10).
///
/// The default is the `#` fragment, so the service worker's `…/match/42` link — and Lane B1's
/// `fcm_options.link` — would open `/` and land the person on S2 instead of S3. The web build
/// switches to the path strategy; a native build has no address to shape.
library;

import 'url_strategy_native.dart'
    if (dart.library.js_interop) 'url_strategy_web.dart' as platform;

/// Called once, before `runApp`, in every flavor's `main`.
void applyUrlStrategy() => platform.applyUrlStrategy();
