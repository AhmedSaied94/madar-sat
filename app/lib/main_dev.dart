import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';

/// Dev flavor: local Compose Caddy at https://localhost:8443.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.ensureConfigured();
  runApp(const ProviderScope(child: MadarApp()));
}
