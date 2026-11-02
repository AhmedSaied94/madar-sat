import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'install_guide.dart';

/// The web answer (research R26): an installed PWA reports `display-mode: standalone`, and
/// Safari reports `navigator.standalone`. iOS Safari outside the PWA cannot be granted push
/// at all (iOS ≥ 16.4 allows Web Push to home-screen apps only), which is what S1.5 guides.
class WebInstallGuide implements InstallGuide {
  const WebInstallGuide();

  @override
  bool get isWeb => true;

  @override
  bool get isInstalled {
    final standalone = web.window.navigator.getProperty('standalone'.toJS);
    if (standalone.isA<JSBoolean>() && (standalone as JSBoolean).toDart) return true;
    return web.window.matchMedia('(display-mode: standalone)').matches;
  }

  @override
  bool get needsInstallSteps {
    final agent = web.window.navigator.userAgent;
    final ios = RegExp(r'iPhone|iPad|iPod').hasMatch(agent);
    // Every other iOS browser is WebKit with a different user agent; only Safari's tabs
    // have the share sheet the three steps describe, so the guide is Safari's alone.
    final otherBrowser =
        agent.contains('CriOS') || agent.contains('FxiOS') || agent.contains('EdgiOS');
    return ios && !otherBrowser && !isInstalled;
  }
}

InstallGuide platformInstallGuide() => const WebInstallGuide();
