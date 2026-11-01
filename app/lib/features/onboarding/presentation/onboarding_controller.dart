import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/settings/settings_providers.dart';
import '../domain/onboarding_step.dart';

part 'onboarding_controller.g.dart';

/// Drives S1.1–S1.4 (research R27): the current step is drift's `onboarding.step`, so
/// quitting mid-flow and reopening resumes where the person stopped, and finishing or
/// skipping writes `onboarding.done` so the flow never appears again.
///
/// Reopening a step from S15 asks for [goTo] only: it writes the step and never touches
/// `onboarding.done`, so a finished onboarding stays finished (US2 scenario 1).
@Riverpod(keepAlive: true)
class OnboardingController extends _$OnboardingController {
  @override
  OnboardingStep build() {
    final settings = ref.watch(appSettingsProvider).value;
    final step = settings?.onboardingStep ?? 0;
    return OnboardingStep.values[step.clamp(0, OnboardingStep.values.length - 1)];
  }

  /// Finishing or skipping: S1 is never shown again.
  Future<void> finish() => ref.read(appSettingsProvider.notifier).completeOnboarding();

  Future<void> goTo(OnboardingStep step) =>
      ref.read(appSettingsProvider.notifier).setOnboardingStep(step.number);

  /// The stored step: the drift row, not this provider's last value, so a write lands on
  /// what the app will resume at even when this provider was not being watched.
  OnboardingStep get _stored {
    final stored = ref.read(settingsProvider).onboardingStep;
    return OnboardingStep.values[stored.clamp(0, OnboardingStep.values.length - 1)];
  }

  Future<void> next() async {
    final following = _stored.next;
    if (following == null) {
      await finish();
      return;
    }
    await goTo(following);
  }

  Future<void> back() async {
    final previous = _stored.previous;
    if (previous != null) await goTo(previous);
  }

  /// «إعادة خطوات البداية» in S15: start over at S1.1, and let the flow show again.
  Future<void> restart() => ref.read(appSettingsProvider.notifier).restartOnboarding();
}
