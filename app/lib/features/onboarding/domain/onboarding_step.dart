/// The onboarding flow's steps (contract app-screens): S1.1 welcome, S1.2 teams, S1.3
/// satellites, S1.4 notifications; S1.5 is a separate route reached from S1.4 on an iPhone
/// whose PWA is not installed (and from S16).
enum OnboardingStep {
  welcome('welcome'),
  teams('teams'),
  satellites('satellites'),
  notifications('notifications');

  const OnboardingStep(this.slug);

  /// The route segment under `/onboarding/`.
  final String slug;

  /// The step's 0-based place, for the progress dots.
  int get number => OnboardingStep.values.indexOf(this);

  OnboardingStep? get next =>
      number + 1 < OnboardingStep.values.length ? OnboardingStep.values[number + 1] : null;

  OnboardingStep? get previous => number > 0 ? OnboardingStep.values[number - 1] : null;

  /// The step for [slug], or welcome for a route this build does not know.
  static OnboardingStep fromSlug(String? slug) => switch (slug) {
        'teams' => OnboardingStep.teams,
        'satellites' => OnboardingStep.satellites,
        'notifications' => OnboardingStep.notifications,
        _ => OnboardingStep.welcome,
      };

  /// The last step the dots count. S1.5 is not one of them: it is a detour, not a step.
  static const int dotCount = 4;
}
