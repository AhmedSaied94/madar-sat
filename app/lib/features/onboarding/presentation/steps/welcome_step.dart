import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/settings_providers.dart';
import '../../../../core/theme/madar_line.dart';
import '../../../../core/theme/madar_tokens.dart';
import '../../../../design/components/logo.dart';
import '../../../../l10n/app_localizations.dart';

/// S1.1: the welcome copy and the theme choice, with a live preview tile per option.
class WelcomeStep extends ConsumerWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final selected = ref.watch(settingsProvider).theme;

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        MadarSpace.s6,
        MadarSpace.s3,
        MadarSpace.s6,
        MadarSpace.s5,
      ),
      child: Column(
        children: [
          _Hero(colors: colors),
          const SizedBox(height: MadarSpace.s3),
          Text(
            l.onbWelcomeTitle,
            textAlign: TextAlign.center,
            style: MadarText.heading1.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: MadarSpace.s2),
          Text(
            l.onbWelcomeBody,
            textAlign: TextAlign.center,
            style: MadarText.textBody.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: MadarSpace.s6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l.onbChooseTheme,
              style: MadarText.textLabel.copyWith(color: colors.textSecondary),
            ),
          ),
          const SizedBox(height: MadarSpace.s2),
          Row(
            children: [
              Expanded(
                child: _ThemeTile(
                  choice: MadarThemeChoice.dark,
                  label: l.themeDark,
                  icon: Icons.dark_mode_outlined,
                  selected: selected == MadarThemeChoice.dark,
                ),
              ),
              const SizedBox(width: MadarSpace.s2),
              Expanded(
                child: _ThemeTile(
                  choice: MadarThemeChoice.light,
                  label: l.themeLight,
                  icon: Icons.light_mode_outlined,
                  selected: selected == MadarThemeChoice.light,
                ),
              ),
              const SizedBox(width: MadarSpace.s2),
              Expanded(
                child: _ThemeTile(
                  choice: MadarThemeChoice.system,
                  label: l.themeAuto,
                  icon: Icons.brightness_auto_outlined,
                  selected: selected == MadarThemeChoice.system,
                ),
              ),
            ],
          ),
          const SizedBox(height: MadarSpace.s2),
          Text(
            l.themeChangeLater,
            textAlign: TextAlign.center,
            style: MadarText.textCaption.copyWith(color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// The orbit motif with the brand mark in the middle (Onb-Welcome).
class _Hero extends StatelessWidget {
  const _Hero({required this.colors});

  final MadarColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MadarSpace.s12 * 4,
      height: MadarSpace.s12 * 3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final side in [MadarSpace.s12 * 4, MadarSpace.s12 * 3, MadarSpace.s12 * 2])
            Container(
              width: side,
              height: side,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.divider, width: MadarLine.hairline),
              ),
            ),
          const BrandMark(size: BrandMarkSize.l64),
          PositionedDirectional(
            top: MadarSpace.s4,
            end: MadarSpace.s4,
            child: Container(
              width: MadarSpace.s2,
              height: MadarSpace.s2,
              decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}

/// One theme option: a miniature of the app in that theme, with a check when chosen.
class _ThemeTile extends ConsumerWidget {
  const _ThemeTile({
    required this.choice,
    required this.label,
    required this.icon,
    required this.selected,
  });

  final MadarThemeChoice choice;
  final String label;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.madarColors;
    final (ground, row) = switch (choice) {
      MadarThemeChoice.dark => (MadarColors.dark.bg, MadarColors.dark.surface2),
      MadarThemeChoice.light => (MadarColors.light.bg, MadarColors.light.surface2),
      MadarThemeChoice.system => (null, null),
    };
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.accentContainer : colors.surface1,
        borderRadius: BorderRadius.circular(MadarRadii.xl),
        child: InkWell(
          borderRadius: BorderRadius.circular(MadarRadii.xl),
          onTap: () => ref.read(appSettingsProvider.notifier).setTheme(choice),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(
              MadarSpace.s2,
              MadarSpace.s2,
              MadarSpace.s2,
              MadarSpace.s2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MadarRadii.xl),
              border: Border.all(
                color: selected ? colors.accent : colors.dividerStrong,
                width: selected ? 2 : MadarLine.hairline,
              ),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(MadarRadii.md),
                      child: Container(
                        height: MadarSpace.s12 + MadarSpace.s12 + MadarSpace.s2,
                        decoration: BoxDecoration(
                          // «تلقائي» is both halves at once, as the board draws it.
                          color: ground,
                          gradient: ground == null
                              ? LinearGradient(
                                  colors: [MadarColors.dark.bg, MadarColors.light.bg],
                                )
                              : null,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(MadarSpace.s1),
                          child: Column(
                            children: [
                              Container(
                                height: MadarSpace.s1,
                                width: MadarSpace.s6,
                                decoration: BoxDecoration(
                                  color: colors.accent,
                                  borderRadius: BorderRadius.circular(MadarRadii.pill),
                                ),
                              ),
                              const SizedBox(height: MadarSpace.s1),
                              for (var i = 0; i < 3; i++) ...[
                                Container(
                                  height: MadarSpace.s3,
                                  decoration: BoxDecoration(
                                    color: row ?? colors.surface2,
                                    borderRadius: BorderRadius.circular(MadarRadii.xs),
                                  ),
                                ),
                                const SizedBox(height: MadarSpace.s1),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (selected)
                      PositionedDirectional(
                        top: MadarSpace.s1,
                        start: MadarSpace.s1,
                        child: Container(
                          width: MadarSpace.s5,
                          height: MadarSpace.s5,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check, size: 14, color: colors.onAccent),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: MadarSpace.s1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: MadarText.textLabel.fontSize, color: colors.textPrimary),
                    const SizedBox(width: MadarSpace.s1),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MadarText.textLabel.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
