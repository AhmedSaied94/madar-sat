import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/build_info.dart';
import '../../../core/links/url_opener.dart';
import '../../../core/platform/install_guide_provider.dart';
import '../../../core/platform/share_service.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/bottom_nav.dart';
import '../../../design/components/list_row.dart';
import '../../../design/components/logo.dart';
import '../../../design/components/banner.dart';
import '../../../l10n/app_localizations.dart';
import '../../system/presentation/system_views.dart';

/// S16 More: settings, share, the privacy policy when its address is configured, the iOS
/// install row on an uninstalled iPhone PWA, and the about card.
///
/// حقوق البث and الفيدات wait for their screens (contract app-screens).
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final guide = ref.watch(installGuideProvider);

    return ExitGuard(
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: MadarSpace.s12 + MadarSpace.s2,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l.navMore,
                      style: MadarText.heading1.copyWith(
                        color: colors.textPrimary,
                        fontSize: MadarText.heading1.fontSize!,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s3),
                  children: [
                    if (guide.needsInstallSteps)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: MadarSpace.s3),
                        child: Material(
                          color: colors.accentContainer,
                          borderRadius: BorderRadius.circular(MadarRadii.xl),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(MadarRadii.xl),
                            onTap: () => context.push('/install'),
                            child: Padding(
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: MadarSpace.s4,
                                vertical: MadarSpace.s3,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: MadarSpace.s12,
                                    height: MadarSpace.s12,
                                    decoration: BoxDecoration(
                                      color: colors.accent,
                                      borderRadius: BorderRadius.circular(MadarRadii.lg),
                                    ),
                                    child: Icon(Icons.add_to_home_screen, color: colors.onAccent),
                                  ),
                                  const SizedBox(width: MadarSpace.s3),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l.onbInstallTitle,
                                          style: MadarText.textBody.copyWith(
                                            color: colors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          l.s16InstallBody,
                                          style: MadarText.textCaption.copyWith(
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: colors.textSecondary),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    MadarListGroup(
                      children: [
                        MadarListRow(
                          icon: Icons.settings_outlined,
                          title: l.settings,
                          subtitle: l.s16SettingsBody,
                          showChevron: true,
                          onTap: () => context.push('/settings'),
                        ),
                        MadarListRow(
                          icon: Icons.share_outlined,
                          title: l.s16Share,
                          subtitle: l.s16ShareBody,
                          showChevron: true,
                          onTap: () async {
                            final text = AppConfig.shareUrl.isEmpty
                                ? l.s16ShareText(l.s16Tagline, '').trim()
                                : l.s16ShareText(l.s16Tagline, AppConfig.shareUrl);
                            final shared = await ref
                                .read(shareServiceProvider)
                                .share(text: text, subject: l.appName);
                            if (!shared && context.mounted) {
                              MadarSnackbar.show(context, l.s3OpenFailed);
                            }
                          },
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
                      ],
                    ),
                    const SizedBox(height: MadarSpace.s6),
                    Column(
                      children: [
                        const BrandMark(size: BrandMarkSize.m40),
                        const SizedBox(height: MadarSpace.s2),
                        Text(
                          l.brandMark,
                          style: MadarText.heading2.copyWith(
                            color: colors.textPrimary,
                            fontSize: MadarText.heading2.fontSize,
                          ),
                        ),
                        const SizedBox(height: MadarSpace.s1),
                        Text(
                          l.s16Tagline,
                          textAlign: TextAlign.center,
                          style: MadarText.textCaption.copyWith(color: colors.textSecondary),
                        ),
                        const SizedBox(height: MadarSpace.s1),
                        Text(
                          l.s16Version(BuildInfo.label),
                          textDirection: TextDirection.ltr,
                          style: MadarText.textMicro.copyWith(color: colors.textTertiary),
                        ),
                      ],
                    ),
                    const SizedBox(height: MadarSpace.s6),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: MadarBottomNav(
          current: MadarTab.more,
          onSelect: (tab) => switch (tab) {
            MadarTab.matches => context.go('/'),
            MadarTab.mySatellites => context.go('/my-satellites'),
            MadarTab.frequencies => context.go('/satellites'),
            MadarTab.favorites => context.go('/favorites'),
            MadarTab.more => context.go('/more'),
          },
        ),
      ),
    );
  }
}
