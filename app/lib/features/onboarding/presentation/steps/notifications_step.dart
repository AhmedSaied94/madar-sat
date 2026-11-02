import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/platform/push_service.dart';
import '../../../../core/db/database_provider.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/settings_providers.dart';
import '../../../../core/theme/madar_line.dart';
import '../../../../core/theme/madar_tokens.dart';
import '../../../../design/components/button.dart';
import '../../../../design/components/logo.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../devices/data/push_token_sync.dart';

/// S1.4: a priming card, then the OS or browser prompt on tap, or «ليس الآن».
///
/// On an iPhone whose PWA is not installed the prompt cannot appear at all, so the step
/// hands over to S1.5 (research R26).
class NotificationsStep extends ConsumerWidget {
  const NotificationsStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final push = ref.watch(pushServiceProvider);

    Future<void> finish({required bool granted}) async {
      await ref.read(appSettingsProvider.notifier).completeOnboarding();
      if (!context.mounted) return;
      context.go('/');
      if (granted) ref.invalidate(pushTokenSyncProvider);
    }

    Future<void> enable() async {
      // An iPhone Safari tab cannot be granted Web Push: S1.5 tells the person to install
      // the app first (R26).
      if (!push.canRequestPermission) {
        if (context.mounted) context.push('/install');
        return;
      }
      final granted = await push.requestPermission();
      if (!context.mounted) return;
      ref.read(pushPermissionProvider.notifier).set(granted);
      await ref
          .read(appDatabaseProvider)
          .writeSetting(SettingsKeys.notificationsAsked, 'true');
      if (!context.mounted) return;
      await finish(granted: granted);
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              MadarSpace.s5,
              0,
              MadarSpace.s5,
              MadarSpace.s4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _NotificationPreview(),
                const SizedBox(height: MadarSpace.s6),
                Text(
                  l.onbNotificationsTitle,
                  style: MadarText.heading2.copyWith(
                    color: colors.textPrimary,
                    fontSize: MadarText.heading1.fontSize!,
                  ),
                ),
                const SizedBox(height: MadarSpace.s1),
                Text(
                  l.onbNotificationsBody,
                  style: MadarText.textLabel.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: MadarSpace.s4),
                for (final benefit in [
                  (Icons.schedule, l.onbBenefitReminders),
                  (Icons.sports_soccer, l.onbBenefitGoals),
                  (Icons.waves, l.onbBenefitFrequency),
                ])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: MadarSpace.s3),
                    child: Row(
                      children: [
                        Container(
                          width: MadarSpace.s8 + MadarSpace.s1,
                          height: MadarSpace.s8 + MadarSpace.s1,
                          decoration: BoxDecoration(
                            color: colors.accentContainer,
                            borderRadius: BorderRadius.circular(MadarRadii.md),
                          ),
                          child: Icon(benefit.$1, size: MadarText.heading2.fontSize, color: colors.accentText),
                        ),
                        const SizedBox(width: MadarSpace.s3),
                        Expanded(
                          child: Text(
                            benefit.$2,
                            style: MadarText.textBody.copyWith(color: colors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            MadarSpace.s4,
            MadarSpace.s3,
            MadarSpace.s4,
            MadarSpace.s5,
          ),
          child: Column(
            children: [
              MadarButton(
                label: l.enableNotifications,
                icon: Icons.notifications_active_outlined,
                expanded: true,
                onPressed: enable,
              ),
              const SizedBox(height: MadarSpace.s1),
              MadarButton(
                label: l.notNow,
                variant: MadarButtonVariant.ghost,
                expanded: true,
                onPressed: () => finish(granted: false),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The three stacked notification cards of the board; a mock of what will arrive, never an
/// OS notification (the app draws it because the OS will).
class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview();

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final cards = [
      (title: 'تغيّر تردد beIN SPORTS 1', body: 'على نايل سات: 11013 H 27500'),
      (title: 'هدف لـ ليفربول!', body: 'ليفربول 1 – 0 تشيلسي · محمد صلاح 23′'),
      (title: 'الزمالك × المقاولون العرب بعد 15 دقيقة', body: 'على أون سبورت · نايل سات'),
    ];
    return Column(
      children: [
        for (final (index, card) in cards.indexed)
          Transform.scale(
            scale: 1 - (cards.length - 1 - index) * 0.03,
            child: Container(
              margin: EdgeInsetsDirectional.only(
                bottom: index == cards.length - 1 ? 0 : MadarSpace.s2,
              ),
              padding: const EdgeInsetsDirectional.all(MadarSpace.s3),
              decoration: BoxDecoration(
                color: colors.surface1,
                borderRadius: BorderRadius.circular(MadarRadii.xl),
                border: Border.all(color: colors.divider, width: MadarLine.hairline),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: MadarSpace.s6 + MadarSpace.s1,
                    height: MadarSpace.s6 + MadarSpace.s1,
                    decoration: BoxDecoration(
                      color: colors.readoutBg,
                      borderRadius: BorderRadius.circular(MadarRadii.sm),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(MadarSpace.s1),
                      child: FittedBox(child: BrandMark(tone: BrandMarkTone.bare)),
                    ),
                  ),
                  const SizedBox(width: MadarSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MadarText.textLabel.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          card.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MadarText.textCaption.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
