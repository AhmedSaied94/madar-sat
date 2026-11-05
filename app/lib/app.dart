import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'core/config/media_image.dart';
import 'core/config/remote_config.dart';
import 'core/router/app_router.dart';
import 'core/settings/settings_providers.dart';
import 'core/theme/madar_theme.dart';
import 'design/components/brand_splash.dart';
import 'design/components/display_scope.dart';
import 'features/devices/data/device_sync.dart';
import 'features/devices/data/push_token_sync.dart';
import 'features/notifications/presentation/push_route_listener.dart';
import 'features/system/data/connectivity.dart';

/// The app root: Arabic only, RTL everywhere, both themes wired to the tokens and the
/// person's settings.
///
/// The router's guard sends a first launch to onboarding and a too-old build to the forced
/// update, and is re-run whenever the settings or the Remote Config values change, so
/// finishing onboarding or raising `min_supported_build` moves the screen at once.
class MadarApp extends ConsumerStatefulWidget {
  const MadarApp({super.key, this.router});

  final GoRouter? router;

  @override
  ConsumerState<MadarApp> createState() => _MadarAppState();
}

class _MadarAppState extends ConsumerState<MadarApp> {
  final _RouterRefresh _refresher = _RouterRefresh();
  late final GoRouter _router =
      widget.router ?? createAppRouter(guard: _guard, refreshListenable: _refresher);

  /// A resume is when unsent device and follow changes are retried (US2 scenario 6): the
  /// attempt made while the phone was offline has no other trigger.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Created now, not on first use: a lazy listener would first exist in `dispose`, and no
    // resume would ever reach it.
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(ref.read(deviceSyncProvider.notifier).sync()),
    );
    unawaited(_launchSync());
  }

  /// The launch attempt: whatever flag the last session left set is sent now (US2 scenario
  /// 6). It waits for the settings, because the sync does nothing before it knows the
  /// onboarding is done.
  Future<void> _launchSync() async {
    try {
      await ref.read(appSettingsProvider.future);
    } on Object {
      // Unreadable settings: the sync below would find none either, and a later trigger
      // (a change, a resume, a reconnect) tries again.
      return;
    }
    if (!mounted) return;
    await ref.read(deviceSyncProvider.notifier).sync();
  }

  /// Where the current location must really go, or null to stay.
  String? _guard(String location) {
    final remote = ref.read(remoteConfigProvider);
    if (remote.updateRequired) {
      return location == '/update-required' ? null : '/update-required';
    }
    if (location == '/update-required') return '/';

    final settings = ref.read(appSettingsProvider).value;
    if (settings == null || settings.onboardingDone) return null;
    if (location.startsWith('/onboarding')) return null;
    // S1.5 is a detour from S1.4 and from S16: a first launch may reach it too.
    if (location == '/install') return null;
    return '/onboarding/${_stepSlug(settings.onboardingStep)}';
  }

  static String _stepSlug(int index) => switch (index) {
        1 => 'teams',
        2 => 'satellites',
        3 => 'notifications',
        _ => 'welcome',
      };

  @override
  void dispose() {
    _lifecycle.dispose();
    _refresher.dispose();
    if (widget.router == null) _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final remote = ref.watch(remoteConfigProvider);
    // A settings change re-runs the guard; the theme and the text scale are read below.
    ref.listen(appSettingsProvider, (_, _) => _refresher.ping());
    ref.listen(remoteConfigProvider, (_, _) => _refresher.ping());
    // The push token and its device sync start with the app, not with a screen.
    ref.watch(pushTokenSyncProvider);
    ref.watch(deviceSyncProvider);
    // Keeps the connectivity state alive for the offline banner.
    ref.watch(connectivityStatusProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: MadarTheme.light,
      darkTheme: MadarTheme.dark,
      themeMode: settings.themeMode,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final deviceScale = media.textScaler.scale(1.0);
        return MediaImageScope(
          mediaBaseUrl: remote.mediaBaseUrl,
          child: MadarDisplayScope(
            zone: settings.zone,
            use24h: settings.use24h,
            child: MediaQuery(
              // The S15 choice on top of the device's own size (S15 «حجم الخط»).
              data: media.copyWith(
                textScaler: TextScaler.linear(deviceScale * settings.fontScale.factor),
              ),
              child: PushRouteListener(
                router: _router,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: BrandSplashGate(child: child ?? const SizedBox.shrink()),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Asks the router to re-run its guard when the settings or the Remote Config values move.
class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}
