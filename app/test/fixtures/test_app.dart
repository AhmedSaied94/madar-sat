import 'package:flutter/material.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

/// Arabic, RTL, themed and animation-free: the host every widget test uses.
Widget testApp(
  Widget child, {
  Brightness brightness = Brightness.dark,
  Widget? bottomNavigationBar,
}) =>
    MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: brightness == Brightness.dark ? MadarTheme.dark : MadarTheme.light,
      builder: (context, appChild) => Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: appChild ?? const SizedBox.shrink(),
        ),
      ),
      home: Scaffold(body: Center(child: child), bottomNavigationBar: bottomNavigationBar),
    );
