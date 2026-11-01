import 'package:flutter_web_plugins/url_strategy.dart';

/// The PWA's routes come from the path (`/match/42`), which is the form the service worker
/// and `fcm_options.link` use (M-R1-10). Firebase Hosting rewrites `**` to `index.html`, so
/// a deep link still loads the app.
void applyUrlStrategy() => usePathUrlStrategy();
