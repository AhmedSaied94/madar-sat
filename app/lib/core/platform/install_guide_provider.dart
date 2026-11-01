import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'install_guide.dart';

part 'install_guide_provider.g.dart';

/// The install guide this platform uses: the web's standalone detection, or "installed" on
/// a native build.
@Riverpod(keepAlive: true)
InstallGuide installGuide(Ref ref) => createInstallGuide();
