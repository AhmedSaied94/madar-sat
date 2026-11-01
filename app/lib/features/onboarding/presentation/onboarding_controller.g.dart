// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives S1.1–S1.4 (research R27): the current step is drift's `onboarding.step`, so
/// quitting mid-flow and reopening resumes where the person stopped, and finishing or
/// skipping writes `onboarding.done` so the flow never appears again.
///
/// Reopening a step from S15 asks for [goTo] only: it writes the step and never touches
/// `onboarding.done`, so a finished onboarding stays finished (US2 scenario 1).

@ProviderFor(OnboardingController)
final onboardingControllerProvider = OnboardingControllerProvider._();

/// Drives S1.1–S1.4 (research R27): the current step is drift's `onboarding.step`, so
/// quitting mid-flow and reopening resumes where the person stopped, and finishing or
/// skipping writes `onboarding.done` so the flow never appears again.
///
/// Reopening a step from S15 asks for [goTo] only: it writes the step and never touches
/// `onboarding.done`, so a finished onboarding stays finished (US2 scenario 1).
final class OnboardingControllerProvider
    extends $NotifierProvider<OnboardingController, OnboardingStep> {
  /// Drives S1.1–S1.4 (research R27): the current step is drift's `onboarding.step`, so
  /// quitting mid-flow and reopening resumes where the person stopped, and finishing or
  /// skipping writes `onboarding.done` so the flow never appears again.
  ///
  /// Reopening a step from S15 asks for [goTo] only: it writes the step and never touches
  /// `onboarding.done`, so a finished onboarding stays finished (US2 scenario 1).
  OnboardingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingControllerHash();

  @$internal
  @override
  OnboardingController create() => OnboardingController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OnboardingStep value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OnboardingStep>(value),
    );
  }
}

String _$onboardingControllerHash() =>
    r'456e2e0a11a64d65f02b59519e7ab3d36f648695';

/// Drives S1.1–S1.4 (research R27): the current step is drift's `onboarding.step`, so
/// quitting mid-flow and reopening resumes where the person stopped, and finishing or
/// skipping writes `onboarding.done` so the flow never appears again.
///
/// Reopening a step from S15 asks for [goTo] only: it writes the step and never touches
/// `onboarding.done`, so a finished onboarding stays finished (US2 scenario 1).

abstract class _$OnboardingController extends $Notifier<OnboardingStep> {
  OnboardingStep build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<OnboardingStep, OnboardingStep>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<OnboardingStep, OnboardingStep>,
              OnboardingStep,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
