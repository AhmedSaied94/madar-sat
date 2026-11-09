import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/generated/models/notification_type.dart';
import '../../../core/platform/install_guide_provider.dart';
import '../../../core/platform/push_service.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/banner.dart';
import '../../../design/components/button.dart';
import '../../../design/components/form_controls.dart';
import '../../../design/components/list_row.dart';
import '../../../l10n/app_localizations.dart';
import '../../devices/data/push_token_sync.dart';
import 'settings_section.dart';

/// How far the type rows dim while the master switch is off.
const double _dimmedOpacity = 0.5;

/// S15's الإشعارات group (FR-063, contract app-screens): the master switch, a switch per type
/// and the platform state.
///
/// An iPhone browser where the app isn't installed can't be granted Web Push, so it gets a link
/// to S1.5 and no switches. Otherwise the choices stay editable whatever the platform says, as
/// on `FollowSheet.html`: they're kept for when notifications are allowed. «التذكير الافتراضي»
/// stays hidden until D8 honours `lead_min`.
class NotificationSettingsGroup extends ConsumerStatefulWidget {
  const NotificationSettingsGroup({super.key});

  @override
  ConsumerState<NotificationSettingsGroup> createState() => _NotificationSettingsGroupState();
}

class _NotificationSettingsGroupState extends ConsumerState<NotificationSettingsGroup> {
  /// The platform's answer, read on opening and on coming back from the device's settings.
  late Future<PushPermissionState> _permission;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _permission = ref.read(pushServiceProvider).permission();
    _lifecycle = AppLifecycleListener(onResume: _reread);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _reread() {
    if (!mounted) return;
    final permission = ref.read(pushServiceProvider).permission();
    setState(() {
      _permission = permission;
    });
  }

  /// «تفعيل», from a tap as iOS and the browser require. A refusal only the device's settings
  /// can lift says so.
  Future<void> _enable() async {
    final granted = await ref.read(pushServiceProvider).requestPermission();
    if (!mounted) return;
    if (granted) {
      ref.read(pushPermissionProvider.notifier).set(true);
      ref.invalidate(pushTokenSyncProvider);
    } else {
      MadarSnackbar.show(context, AppLocalizations.of(context).pushPermissionDenied);
    }
    _reread();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (ref.watch(installGuideProvider).needsInstallSteps) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSectionTitle(l.s15SectionNotifications),
          SettingsCard(
            children: [
              MadarListRow(
                icon: Icons.install_mobile,
                title: l.s16InstallRow,
                subtitle: l.s16InstallBody,
                showChevron: true,
                onTap: () => context.push('/install'),
              ),
            ],
          ),
        ],
      );
    }

    final choices = ref.watch(settingsProvider).notificationChoices;
    final notifier = ref.read(appSettingsProvider.notifier);
    void save(NotificationChoices next) => unawaited(notifier.setNotifications(next));

    return FutureBuilder<PushPermissionState>(
      future: _permission,
      builder: (context, permission) {
        final allowed = permission.data == PushPermissionState.allowed;
        final known = permission.hasData;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsSectionTitle(l.s15SectionNotifications),
            SettingsCard(
              children: [
                _SwitchRow(
                  icon: Icons.notifications,
                  title: l.s15AllowNotifications,
                  subtitle: allowed ? l.s15AllowedHere : null,
                  value: choices.enabled,
                  onChanged: (value) => save(choices.withEnabled(value)),
                ),
                for (final row in _typeRows(l))
                  Opacity(
                    opacity: choices.enabled ? 1 : _dimmedOpacity,
                    child: _SwitchRow(
                      icon: row.icon,
                      title: row.title,
                      enabled: choices.enabled,
                      value: choices.isOn(row.type),
                      onChanged: (value) => save(choices.withType(row.type, value)),
                    ),
                  ),
              ],
            ),
            if (known && !allowed) _PermissionOff(onEnable: _enable),
          ],
        );
      },
    );
  }

  static List<({NotificationType type, IconData icon, String title})> _typeRows(
    AppLocalizations l,
  ) =>
      [
        (type: NotificationType.kickoffReminder, icon: Icons.schedule, title: l.s15NotifReminder),
        (type: NotificationType.matchStarted, icon: Icons.sports, title: l.s15NotifStarted),
        (type: NotificationType.goal, icon: Icons.sports_soccer, title: l.s15NotifGoals),
        (type: NotificationType.finalScore, icon: Icons.check, title: l.s15NotifFinal),
        (type: NotificationType.channelsUpdated, icon: Icons.tv, title: l.s15NotifChannels),
        (type: NotificationType.frequencyChanged, icon: Icons.graphic_eq, title: l.s15NotifFrequency),
        (
          type: NotificationType.announcement,
          icon: Icons.chat_bubble_outline,
          title: l.s15NotifAnnouncements,
        ),
      ];
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        // One node for the row, or a screen reader would say the title twice.
        container: true,
        toggled: value,
        enabled: enabled,
        label: subtitle == null ? title : '$title، $subtitle',
        onTap: enabled ? () => onChanged(!value) : null,
        excludeSemantics: true,
        child: MadarListRow(
          icon: icon,
          title: title,
          subtitle: subtitle,
          onTap: enabled ? () => onChanged(!value) : null,
          trailing: MadarSwitch(value: value, onChanged: onChanged, label: title, enabled: enabled),
        ),
      );
}

/// The steps to enable, in `FollowSheet.html`'s words: the `postponed` warning banner.
class _PermissionOff extends StatelessWidget {
  const _PermissionOff({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        MadarSpace.s4,
        MadarSpace.s2,
        MadarSpace.s4,
        0,
      ),
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: MadarSpace.s3,
          vertical: MadarSpace.s3,
        ),
        decoration: BoxDecoration(
          color: colors.postponedContainer,
          borderRadius: BorderRadius.circular(MadarRadii.lg),
        ),
        child: Row(
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: MadarText.textBody.fontSize,
              color: colors.postponed,
            ),
            const SizedBox(width: MadarSpace.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.s15DeniedTitle,
                    style: MadarText.textLabel.copyWith(color: colors.postponed),
                  ),
                  Text(
                    l.s15DeniedBody,
                    style: MadarText.textCaption.copyWith(color: colors.postponed),
                  ),
                ],
              ),
            ),
            const SizedBox(width: MadarSpace.s2),
            // The board's filled `xs` button: `postponed` with `bg` text, which passes WCAG AA
            // in both themes where a bare `TextButton`'s volt label doesn't (review M-R1-1).
            MadarButton(
              label: l.s15DeniedAction,
              onPressed: onEnable,
              variant: MadarButtonVariant.secondary,
              size: MadarButtonSize.extraSmall,
              background: colors.postponed,
              foreground: colors.bg,
            ),
          ],
        ),
      ),
    );
  }
}
