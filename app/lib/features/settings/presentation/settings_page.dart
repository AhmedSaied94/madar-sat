import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/build_info.dart';
import '../../../core/format/time.dart';
import '../../../core/links/url_opener.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/dialog.dart';
import '../../../design/components/list_row.dart';
import '../../../design/components/segmented.dart';
import '../../../design/components/top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../follows/data/follows_repository.dart';
import '../../devices/data/device_identity_provider.dart';
import '../../my_satellites/data/my_satellites_provider.dart';
import '../../onboarding/presentation/steps/satellites_step.dart';
import '../../../core/config/app_config.dart';

/// S15 Settings, D3's core scope: التوقيت, المظهر, أقماري, خطوات البداية and عن التطبيق.
///
/// Notifications, the competitions order and the data group wait for V1/D8 (contract
/// app-screens); this screen shows only what the app honors today.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key, this.section});

  /// `time`, `appearance`, `satellites`, `about`: the sub-route, or null for the whole page.
  final String? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    if (section == 'satellites') {
      return Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Column(
            children: [
              MadarTopBar.detail(
                title: l.s15ChooseSatellites,
                onBack: context.pop,
              ),
              const Expanded(child: SatellitesStep(showNote: false)),
            ],
          ),
        ),
      );
    }

    final showAll = section == null;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            MadarTopBar.detail(
              title: l.settings,
              onBack: context.canPop() ? context.pop : () => context.go('/more'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.only(bottom: MadarSpace.s8),
                children: [
                  if (showAll || section == 'time') ...[
                    _SectionTitle(l.s15SectionTime),
                    _Card(
                      children: [
                        MadarListRow(
                          icon: Icons.public,
                          title: l.s15TimeZone,
                          value: settings.zone.fixed == null
                              ? l.s15AutomaticWithOffset(_gmt(Duration(hours: DateTime.now().timeZoneOffset.inHours)))
                              : settings.zone.label(l.themeAuto),
                          showChevron: true,
                          onTap: () => _pickZone(context, ref, settings),
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            MadarSpace.s4,
                            0,
                            MadarSpace.s4,
                            MadarSpace.s3,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.s15TimeFormat,
                                style: MadarText.textBody.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: MadarSpace.s2),
                              Segmented<MadarTimeFormat>(
                                selected: settings.timeFormat,
                                onChanged: (value) => notifier.setTimeFormat(value),
                                options: [
                                  SegmentedOption(
                                    value: MadarTimeFormat.h12,
                                    label: l.s15H12(_sample(context, const Duration(hours: 21), false)),
                                  ),
                                  SegmentedOption(
                                    value: MadarTimeFormat.h24,
                                    label: l.s15H24(_sample(context, const Duration(hours: 21), true)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (showAll || section == 'appearance') ...[
                    _SectionTitle(l.s15SectionAppearance),
                    _Card(
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            MadarSpace.s4,
                            MadarSpace.s3,
                            MadarSpace.s4,
                            MadarSpace.s3,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.s15Mode,
                                style: MadarText.textBody.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: MadarSpace.s2),
                              Segmented<MadarThemeChoice>(
                                selected: settings.theme,
                                onChanged: (value) => notifier.setTheme(value),
                                options: [
                                  SegmentedOption(
                                    value: MadarThemeChoice.dark,
                                    label: l.themeDark,
                                    icon: Icons.dark_mode_outlined,
                                  ),
                                  SegmentedOption(
                                    value: MadarThemeChoice.light,
                                    label: l.themeLight,
                                    icon: Icons.light_mode_outlined,
                                  ),
                                  SegmentedOption(
                                    value: MadarThemeChoice.system,
                                    label: l.themeAuto,
                                    icon: Icons.brightness_auto_outlined,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        MadarListRow(
                          icon: Icons.format_size,
                          title: l.s15FontSize,
                          subtitle: l.s15FontNote,
                          trailing: SizedBox(
                            width: MadarSpace.s12 * 4,
                            child: Segmented<MadarFontScale>(
                              selected: settings.fontScale,
                              onChanged: (value) => notifier.setFontScale(value),
                              options: [
                                SegmentedOption(
                                  value: MadarFontScale.normal,
                                  label: l.s15FontNormal,
                                ),
                                SegmentedOption(
                                  value: MadarFontScale.large,
                                  label: l.s15FontLarge,
                                ),
                                SegmentedOption(
                                  value: MadarFontScale.xlarge,
                                  label: l.s15FontXLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (showAll || section == 'satellites') ...[
                    _SectionTitle(l.s15SectionSatellites),
                    _Card(
                      children: [
                        MadarListRow(
                          icon: Icons.satellite_alt,
                          title: l.s15ChooseSatellites,
                          subtitle: _satelliteNames(ref, l),
                          showChevron: true,
                          onTap: () => context.push('/settings/satellites'),
                        ),
                      ],
                    ),
                  ],
                  if (showAll) ...[
                    _SectionTitle(l.s15SectionOnboarding),
                    _Card(
                      children: [
                        MadarListRow(
                          icon: Icons.restart_alt,
                          title: l.s15RestartOnboarding,
                          showChevron: true,
                          onTap: () => context.push('/onboarding/welcome'),
                        ),
                      ],
                    ),
                    _SectionTitle(l.s15SectionAbout),
                    _Card(
                      children: [
                        MadarListRow(
                          icon: Icons.info_outline,
                          title: l.s15Version,
                          value: BuildInfo.label,
                        ),
                        if (AppConfig.privacyUrl.isNotEmpty)
                          MadarListRow(
                            icon: Icons.shield_outlined,
                            title: l.s15Privacy,
                            showChevron: true,
                            onTap: () => ref
                                .read(urlOpenerProvider)
                                .open(Uri.parse(AppConfig.privacyUrl)),
                          ),
                        MadarListRow(
                          icon: Icons.delete_outline,
                          title: l.s15DeleteDevice,
                          subtitle: l.s15DeleteDeviceBody,
                          danger: true,
                          showChevron: true,
                          onTap: () => _deleteDevice(context, ref, l),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// «نايل سات، بدر», or the prompt while nothing is chosen.
  static String _satelliteNames(WidgetRef ref, AppLocalizations l) {
    final names = ref.watch(mySatelliteNamesProvider);
    return names.isEmpty ? l.s15NoSatellites : names.join('، ');
  }

  static String _gmt(Duration offset) {
    final sign = offset.isNegative ? '−' : '+';
    final hours = offset.inHours.abs();
    final minutes = offset.inMinutes.abs() % 60;
    return 'GMT$sign$hours${minutes == 0 ? '' : ':${minutes.toString().padLeft(2, '0')}'}';
  }

  /// A sample time for the two segmented labels: 9:00 م and 21:00.
  static String _sample(BuildContext context, Duration wall, bool use24h) {
    final kickoff = DateTime.utc(2000, 1, 1).add(wall);
    final l = AppLocalizations.of(context);
    return MadarTime.kickoff(
          kickoff,
          am: l.amMarker,
          pm: l.pmMarker,
          use24h: use24h,
        ) ??
        '';
  }

  Future<void> _pickZone(BuildContext context, WidgetRef ref, AppSettingsValue settings) async {
    final l = AppLocalizations.of(context);
    final chosen = await showModalBottomSheet<MadarZone>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ZoneSheet(selected: settings.zone, l: l),
    );
    if (chosen == null) return;
    await ref.read(appSettingsProvider.notifier).setZone(chosen);
  }

  Future<void> _deleteDevice(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) async {
    final confirmed = await showMadarDialog(
      context,
      title: l.s15DeleteTitle,
      body: l.s15DeleteConsequence,
      confirmLabel: l.delete,
    );
    if (!confirmed || !context.mounted) return;
    // The server call (`DELETE /v1/devices/me`) ships with T133's device client; until then
    // the device's own data is cleared here and the token is dropped, so no further request
    // counts against this install.
    await ref.read(followsRepositoryProvider).clear();
    await ref.read(deviceIdentityControllerProvider.notifier).forget();
    if (!context.mounted) return;
    context.go('/onboarding/welcome');
  }
}

/// The bottom sheet of time zones: automatic, then GMT−12 … GMT+14.
class _ZoneSheet extends StatelessWidget {
  const _ZoneSheet({required this.selected, required this.l});

  final MadarZone selected;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.all(MadarSpace.s4),
              child: Text(
                l.s15TimeZone,
                style: MadarText.heading2.copyWith(color: colors.textPrimary),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final zone in [
                    const MadarZone.auto(),
                    for (var minutes = -12 * 60; minutes <= 14 * 60; minutes += 60)
                      MadarZone.fixed(Duration(minutes: minutes)),
                  ])
                    MadarListRow(
                      title: zone.fixed == null
                          ? l.s15AutomaticWithOffset(
                              'GMT${DateTime.now().timeZoneOffset.isNegative ? '−' : '+'}'
                              '${DateTime.now().timeZoneOffset.inHours.abs()}',
                            )
                          : zone.label(''),
                      trailing: zone == selected
                          ? Icon(Icons.check, color: colors.accentText)
                          : null,
                      onTap: () => Navigator.of(context).pop(zone),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          MadarSpace.s6,
          MadarSpace.s5,
          MadarSpace.s6,
          MadarSpace.s2,
        ),
        child: Text(
          title,
          style: MadarText.textCaption.copyWith(
            color: context.madarColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
        child: MadarListGroup(children: children),
      );
}
