import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/madar_theme.dart';

/// The app root: Arabic only, RTL everywhere, both themes wired to the tokens.
class MadarApp extends StatefulWidget {
  const MadarApp({super.key, this.router});

  final GoRouter? router;

  @override
  State<MadarApp> createState() => _MadarAppState();
}

class _MadarAppState extends State<MadarApp> {
  late final GoRouter _router = widget.router ?? createAppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: MadarTheme.light,
      darkTheme: MadarTheme.dark,
      themeMode: ThemeMode.dark,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
