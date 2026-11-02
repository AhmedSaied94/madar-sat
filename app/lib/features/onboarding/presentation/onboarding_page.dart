import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/settings_providers.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/button.dart';
import '../../../design/components/progress_dots.dart';
import '../../../l10n/app_localizations.dart';
import '../../follows/data/follows_repository.dart';
import '../domain/onboarding_step.dart';
import 'onboarding_controller.dart';
import 'steps/notifications_step.dart';
import 'steps/satellites_step.dart';
import 'steps/teams_step.dart';
import 'steps/welcome_step.dart';

/// S1.1–S1.4: one route per step, the same chrome above and the same footer below
/// (`/onboarding/:step`, contract app-screens).
///
/// The router sends a first launch here and keeps it here until `onboarding.done`; moving to
/// the next step writes drift and then the next route, so a relaunch resumes at the same
/// place.
class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key, required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final controller = ref.read(onboardingControllerProvider.notifier);
    final follows = ref.watch(followSetValueProvider);
    final settings = ref.watch(settingsProvider);

    Future<void> goNext() async {
      final following = step.next;
      if (following == null) {
        await controller.finish();
        if (context.mounted) context.go('/');
        return;
      }
      await controller.goTo(following);
      if (context.mounted) context.go('/onboarding/${following.slug}');
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Chrome(step: step),
            Expanded(
              child: switch (step) {
                OnboardingStep.welcome => const WelcomeStep(),
                OnboardingStep.teams => const TeamsStep(),
                OnboardingStep.satellites => const SatellitesStep(),
                OnboardingStep.notifications => const NotificationsStep(),
              },
            ),
            if (step != OnboardingStep.notifications)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  MadarSpace.s4,
                  MadarSpace.s3,
                  MadarSpace.s4,
                  MadarSpace.s5,
                ),
                child: MadarButton(
                  label: switch (step) {
                    OnboardingStep.teams when follows.total > 0 =>
                      l.nextCount(follows.total),
                    OnboardingStep.satellites when settings.satelliteIds.isNotEmpty =>
                      l.nextCount(settings.satelliteIds.length),
                    _ => l.next,
                  },
                  // S1.2–S1.4's forward action: the arrow sits after the label and, mirrored
                  // in RTL, points left (constitution III, `Onb-Teams.png`).
                  trailingIcon: Icons.arrow_forward,
                  expanded: true,
                  onPressed: goNext,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Back, the progress dots and «تخطي» (S1 boards).
class _Chrome extends ConsumerWidget {
  const _Chrome({required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final controller = ref.read(onboardingControllerProvider.notifier);
    return SizedBox(
      height: MadarSpace.s12 + MadarSpace.s2,
      child: Row(
        children: [
          SizedBox(
            width: MadarSpace.s12,
            child: step.previous == null
                ? null
                : IconButton(
                    tooltip: l.back,
                    onPressed: () async {
                      final previous = step.previous!;
                      await controller.back();
                      if (context.mounted) context.go('/onboarding/${previous.slug}');
                    },
                    // Back: mirrored in RTL, `arrow_back` points right, the way back reads.
                    icon: const Icon(Icons.arrow_back),
                  ),
          ),
          Expanded(
            child: Center(
              child: ProgressDots(
                current: step.number,
                count: OnboardingStep.dotCount,
                semanticsLabel: l.onbProgress(step.number + 1, OnboardingStep.dotCount),
              ),
            ),
          ),
          SizedBox(
            width: MadarSpace.s12 + MadarSpace.s6,
            child: step == OnboardingStep.notifications
                ? null
                : Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () async {
                        await controller.finish();
                        if (context.mounted) context.go('/');
                      },
                      child: Text(l.skip),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
