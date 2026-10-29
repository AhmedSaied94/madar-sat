import 'package:flutter/material.dart';

import 'madar_tokens.dart';

/// The app themes: nothing but the token-generated [buildMadarTheme], wired for Arabic.
/// The app forces RTL and the `ar` locale in [MadarApp]; widgets read tokens through
/// `context.madarColors`.
abstract final class MadarTheme {
  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final base = buildMadarTheme(brightness);
    final colors = brightness == Brightness.dark ? MadarColors.dark : MadarColors.light;
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: MadarFonts.sans,
        bodyColor: colors.textPrimary,
        displayColor: colors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
