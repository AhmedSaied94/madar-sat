import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/remote_config.dart';
import 'core/config/remote_config_repository.dart';
import 'core/platform/firebase_bootstrap.dart';
import 'core/platform/url_strategy.dart';

/// The staging flavor: the staging flavor.
///
/// Firebase starts from `env/staging.json`'s public identifiers (no-op when they are absent),
/// then Remote Config answers and its values are handed to the app before the first frame,
/// so the API and media hosts never change mid-session (research R28).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // `/match/42` from a notification link is a path, not a fragment (M-R1-10).
  applyUrlStrategy();
  AppConfig.ensureConfigured();
  await FirebaseBootstrap.start();
  final remote = await const RemoteConfigRepository().load();
  runApp(
    ProviderScope(
      overrides: [remoteConfigProvider.overrideWithValue(remote)],
      child: const MadarApp(),
    ),
  );
}
