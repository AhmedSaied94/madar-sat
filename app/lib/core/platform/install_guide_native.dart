import 'package:flutter/foundation.dart';

import 'install_guide.dart';

/// The native answer: the app is installed by definition, and no iOS install guide can
/// apply (an iPhone native build receives APNs pushes like any app).
class NativeInstallGuide implements InstallGuide {
  const NativeInstallGuide();

  @override
  bool get isWeb => false;

  @override
  bool get isInstalled => true;

  @override
  bool get needsInstallSteps => false;
}

InstallGuide platformInstallGuide() {
  // The guard is a compile-time jest: a native build has no browser globals at all.
  assert(!kIsWeb, 'the web install guide must be chosen on the web');
  return const NativeInstallGuide();
}
