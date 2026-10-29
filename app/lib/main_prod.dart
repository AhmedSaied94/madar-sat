import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';

/// Prod flavor: VPS-1 over HTTPS.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.ensureConfigured();
  runApp(const ProviderScope(child: MadarApp()));
}
