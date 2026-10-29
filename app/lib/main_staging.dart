import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';

/// Staging flavor: the LAN Caddy over HTTPS (no staging server exists, SD §11).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.ensureConfigured();
  runApp(const ProviderScope(child: MadarApp()));
}
