/// Whether this install is a browser tab or an installed PWA, and whether the iOS install
/// guide applies (research R26, R28).
///
/// Android and iOS builds answer "installed": there is nothing to guide. The web build
/// reads `navigator.standalone` and the display-mode media query, chosen by a conditional
/// import so a native build never compiles the browser code.
library;

import 'install_guide_native.dart'
    if (dart.library.js_interop) 'install_guide_web.dart' as platform;

abstract interface class InstallGuide {
  /// True when an installed PWA and a plain Safari tab can be told apart on this platform.
  bool get isWeb;

  /// True when the app runs from the home screen (or as an installed app).
  bool get isInstalled;

  /// iOS Safari *not* installed: push cannot be granted, so S1.4 shows S1.5 instead.
  bool get needsInstallSteps;
}

/// The guide in force: the web implementation on the web, "installed" everywhere else.
InstallGuide createInstallGuide() => platform.platformInstallGuide();
