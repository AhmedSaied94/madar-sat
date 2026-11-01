import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/settings/settings_providers.dart';
import 'package:madar_sat/features/onboarding/domain/onboarding_step.dart';
import 'package:madar_sat/features/onboarding/presentation/onboarding_controller.dart';

/// S1's controller (US2 scenario 1, research R27): steps move, skip finishes, the step
/// survives a restart, and reopening a step from S15 never un-finishes onboarding.
void main() {
  late AppDatabase database;
  late ProviderContainer container;

  OnboardingController controller() =>
      container.read(onboardingControllerProvider.notifier);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory(), now: () => DateTime.utc(2026, 11, 1, 9));
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    // Hold the settings stream the way the router does, so it stays alive.
    container.listen(appSettingsProvider, (_, _) {});
  });

  Future<void> ready() async {
    await container.read(appSettingsProvider.future);
  }

  /// Lets a write reach drift, the settings future resolve and the controller rebuild.
  Future<void> settle() async {
    await pumpEventQueue();
    await container.read(appSettingsProvider.future);
    await pumpEventQueue();
  }

  test('a fresh install starts at welcome', () async {
    await ready();
    expect(container.read(onboardingControllerProvider), OnboardingStep.welcome);
  });

  test('next walks the four steps and the last one finishes the flow', () async {
    await ready();

    await controller().next();
    await settle();
    expect(container.read(settingsProvider).onboardingStep, 1);

    await controller().next();
    await settle();
    expect(container.read(settingsProvider).onboardingStep, 2);

    await controller().next();
    await settle();
    expect(container.read(settingsProvider).onboardingStep, 3);

    await controller().next();
    await settle();
    expect(container.read(settingsProvider).onboardingDone, isTrue);
  });

  test('back goes one step and stops at welcome', () async {
    await ready();
    await controller().next();
    await settle();
    await controller().next();
    await settle();
    await controller().back();
    await settle();
    expect(container.read(settingsProvider).onboardingStep, 1);
    await controller().back();
    await settle();
    await controller().back();
    await settle();
    expect(container.read(settingsProvider).onboardingStep, 0);
  });

  test('skip finishes without walking the rest, and never shows the flow again', () async {
    await ready();
    await controller().finish();
    await settle();

    expect(container.read(settingsProvider).onboardingDone, isTrue);

    // A second launch reads the same drift rows: still done.
    final relaunch = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(relaunch.dispose);
    relaunch.listen(appSettingsProvider, (_, _) {});
    await relaunch.read(appSettingsProvider.future);
    expect(relaunch.read(settingsProvider).onboardingDone, isTrue);
  });

  test('a restart resumes at the stored step', () async {
    await ready();
    await controller().next();
    await settle();
    await controller().next();
    await settle();

    final relaunch = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(relaunch.dispose);
    relaunch.listen(appSettingsProvider, (_, _) {});
    await relaunch.read(appSettingsProvider.future);
    expect(relaunch.read(settingsProvider).onboardingStep, 2);
  });

  test('a step reopened from S15 publishes its step and never resets onboarding_done', () async {
    await ready();
    await controller().finish();
    await settle();

    await controller().goTo(OnboardingStep.satellites);
    await settle();

    expect(container.read(settingsProvider).onboardingStep, 2);
    expect(container.read(settingsProvider).onboardingDone, isTrue);
  });

  test('«إعادة خطوات البداية» opens the flow again from S1.1', () async {
    await ready();
    await controller().finish();
    await settle();

    await controller().restart();
    await settle();

    expect(container.read(settingsProvider).onboardingDone, isFalse);
    expect(container.read(settingsProvider).onboardingStep, 0);
  });
}
