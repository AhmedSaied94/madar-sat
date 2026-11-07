import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/platform/install_guide.dart';
import 'package:madar_sat/core/platform/install_guide_provider.dart';
import 'package:madar_sat/core/platform/push_service.dart';
import 'package:madar_sat/core/settings/app_settings.dart';
import 'package:madar_sat/features/settings/presentation/notification_settings.dart';

import 'golden_harness.dart';

class _Push extends NoPushService {
  const _Push(this.answer);

  final PushPermissionState answer;

  @override
  Future<PushPermissionState> permission() async => answer;
}

class _Guide implements InstallGuide {
  const _Guide({this.needsInstallSteps = false});

  @override
  bool get isWeb => needsInstallSteps;

  @override
  bool get isInstalled => !needsInstallSteps;

  @override
  final bool needsInstallSteps;
}

/// S15's الإشعارات group in each state (T102, FR-063, FR-064).
void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory(), now: () => DateTime.utc(2026, 11, 1, 9));
  });

  tearDown(() => database.close());

  Widget group(PushPermissionState state, {InstallGuide guide = const _Guide()}) => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          pushServiceProvider.overrideWithValue(_Push(state)),
          installGuideProvider.overrideWithValue(guide),
        ],
        child: const NotificationSettingsGroup(),
      );

  const size = Size(360, 760);

  testWidgets('allowed', (tester) async {
    await goldenVariants(
      tester,
      'settings_notifications_allowed',
      (context) => group(PushPermissionState.allowed),
      size: size,
    );
  });

  testWidgets('denied', (tester) async {
    await goldenVariants(
      tester,
      'settings_notifications_denied',
      (context) => group(PushPermissionState.denied),
      size: size,
    );
  });

  testWidgets('master off dims the types', (tester) async {
    await database.writeSetting(
      SettingsKeys.notificationPrefs,
      const NotificationChoices(enabled: false).encode(),
    );
    await goldenVariants(
      tester,
      'settings_notifications_master_off',
      (context) => group(PushPermissionState.allowed),
      size: size,
    );
  });

  testWidgets('an iPhone browser', (tester) async {
    await goldenVariants(
      tester,
      'settings_notifications_install',
      (context) => group(
        PushPermissionState.denied,
        guide: const _Guide(needsInstallSteps: true),
      ),
      size: const Size(360, 160),
    );
  });
}
