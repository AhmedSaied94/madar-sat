import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/build_info.dart';
import '../../../core/format/digits.dart';
import '../../../core/format/time.dart';
import '../../../core/l10n/error_copy.dart';
import '../../../core/links/url_opener.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/banner.dart';
import '../../../design/components/dialog.dart';
import '../../../design/components/list_row.dart';
import '../../../design/components/segmented.dart';
import '../../../design/components/top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../devices/data/device_identity_provider.dart';
import '../../devices/data/device_repository.dart';
import '../../follows/data/follows_repository.dart';
import '../../my_satellites/data/my_satellites_provider.dart';
import '../../onboarding/presentation/steps/satellites_step.dart';
import 'notification_settings.dart';
import 'settings_section.dart';
import '../../../core/config/app_config.dart';

/// S15 Settings: التوقيت, المظهر, الإشعارات, أقماري, خطوات البداية and عن التطبيق.
///
/// The competitions order and the data group wait for V1/D8 (contract app-screens); this
/// screen shows only what the app honors today.
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
                    SettingsSectionTitle(l.s15SectionTime),
                    SettingsCard(
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
                    SettingsSectionTitle(l.s15SectionAppearance),
                    SettingsCard(
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
                  if (showAll) const NotificationSettingsGroup(),
                  if (showAll || section == 'satellites') ...[
                    SettingsSectionTitle(l.s15SectionSatellites),
                    SettingsCard(
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
                    SettingsSectionTitle(l.s15SectionOnboarding),
                    SettingsCard(
                      children: [
                        MadarListRow(
                          icon: Icons.restart_alt,
                          title: l.s15RestartOnboarding,
                          showChevron: true,
                          onTap: () => context.push('/onboarding/welcome'),
                        ),
                      ],
                    ),
                    SettingsSectionTitle(l.s15SectionAbout),
                    SettingsCard(
                      children: [
                        MadarListRow(
                          icon: Icons.info_outline,
                          title: l.s15Version,
                          value: BuildInfo.label,
                        ),
                        if (settings.deviceId case final id?)
                          MadarListRow(
                            icon: Icons.tag,
                            title: l.s15DeviceId,
                            value: MadarDigits.plain(id),
                            trailing: Icon(
                              Icons.copy,
                              size: MadarText.textBody.fontSize,
                              color: colors.textTertiary,
                            ),
                            onTap: () => _copyDeviceId(context, l, id),
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

  /// So an admin can save this device as their test device (FR-062).
  static Future<void> _copyDeviceId(BuildContext context, AppLocalizations l, int id) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: MadarDigits.plain(id)));
    messenger?.showSnackBar(SnackBar(content: Text(l.s15DeviceIdCopied)));
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
    // The server row goes first (US2 scenario 10): only a `204` wipes the device locally, so
    // a failure keeps the follows, the settings and the token, and says what went wrong.
    final repository = ref.read(deviceRepositoryProvider);
    try {
      final identity = await repository.identity();
      // No token means no server row to delete: the local wipe is the whole story.
      if (identity.token != null) await repository.deleteDevice();
    } on ApiFailure catch (failure) {
      if (!context.mounted) return;
      MadarSnackbar.show(context, l.failureCopy(failure));
      return;
    }
    await ref.read(followsRepositoryProvider).clear();
    await ref.read(deviceIdentityControllerProvider.notifier).forget();
    // The theme, the zone, the satellites and `onboardingDone` are read through a kept-alive
    // provider: without this it would keep the old value until a restart.
    ref.invalidate(appSettingsProvider);
    if (!context.mounted) return;
    MadarSnackbar.show(context, l.s15Deleted);
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
