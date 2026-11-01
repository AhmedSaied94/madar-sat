import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/build_info.dart';
import '../../../core/l10n/error_copy.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/platform/reload_page.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/banner.dart';
import '../../../design/components/button.dart';
import '../../../design/components/empty_state.dart';
import '../../../l10n/app_localizations.dart';

/// S0's no-connection screen: the orbit illustration, the words, and «إعادة المحاولة»
/// (research R29, `Sys-NoConnection`).
class NoConnectionView extends StatelessWidget {
  const NoConnectionView({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return EmptyState(
      kind: EmptyStateKind.error,
      title: l.noConnectionTitle,
      body: l.noConnectionBody,
      action: MadarButton(
        label: l.retry,
        icon: Icons.refresh,
        variant: MadarButtonVariant.secondary,
        onPressed: onRetry,
      ),
    );
  }
}

/// S0's load-failed screen: the server answered with an error (or an unreadable body), so
/// the copy is the API's code in words, never the server's message (`Sys-LoadFailed`).
class LoadFailedView extends StatelessWidget {
  const LoadFailedView({super.key, this.failure, this.onRetry, this.retrying = false});

  final ApiFailure? failure;
  final VoidCallback? onRetry;
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final code = failure?.code;
    return EmptyState(
      kind: EmptyStateKind.error,
      title: l.loadFailedTitle,
      body: code == null ? l.s0LoadFailedBody : l.errorCopy(code),
      action: retrying
          ? MadarButton(
              label: l.s0Retrying,
              variant: MadarButtonVariant.secondary,
              busy: true,
              onPressed: null,
            )
          : MadarButton(
              label: l.retry,
              icon: Icons.refresh,
              variant: MadarButtonVariant.secondary,
              onPressed: onRetry,
            ),
    );
  }
}

/// One of the two, by the failure: offline gets its own words (constitution III).
class SystemFailureView extends StatelessWidget {
  const SystemFailureView({
    super.key,
    required this.failure,
    this.onRetry,
    this.retrying = false,
  });

  final ApiFailure failure;
  final VoidCallback? onRetry;
  final bool retrying;

  @override
  Widget build(BuildContext context) => failure.isOffline
      ? NoConnectionView(onRetry: onRetry)
      : LoadFailedView(failure: failure, onRetry: onRetry, retrying: retrying);
}

/// S0's forced update: shown before the shell when the build is below Remote Config's
/// `min_supported_build` (`Sys-ForcedUpdate`, research R28).
class ForcedUpdatePage extends ConsumerWidget {
  const ForcedUpdatePage({super.key});

  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.madarsat.app';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: EmptyState(
                  kind: EmptyStateKind.error,
                  title: l.s0UpdateTitle,
                  body: l.s0UpdateBody,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                MadarSpace.s5,
                0,
                MadarSpace.s5,
                MadarSpace.s6,
              ),
              child: Column(
                children: [
                  MadarButton(
                    label: l.s0UpdateNow,
                    icon: Icons.download,
                    expanded: true,
                    onPressed: () => reloadPage(),
                  ),
                  const SizedBox(height: MadarSpace.s1),
                  Text(
                    l.s0YourVersion(BuildInfo.label),
                    textDirection: TextDirection.ltr,
                    style: MadarText.textMicro.copyWith(color: colors.textTertiary),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: MadarSpace.s1),
                    Text(
                      l.s0UpdateOpensStore,
                      style: MadarText.textMicro.copyWith(color: colors.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Android exit rule (S0): on a root tab, back shows «اضغط رجوع مرة أخرى للخروج» and a
/// second back within two seconds leaves the app. Other platforms keep their own back.
class ExitGuard extends StatefulWidget {
  const ExitGuard({super.key, required this.child});

  final Widget child;

  @override
  State<ExitGuard> createState() => _ExitGuardState();
}

class _ExitGuardState extends State<ExitGuard> {
  bool _armed = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final android = defaultTargetPlatform == TargetPlatform.android && !kIsWeb;
    return PopScope(
      canPop: !android,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !android) return;
        if (_armed) {
          SystemNavigator.pop();
          return;
        }
        setState(() => _armed = true);
        MadarSnackbar.show(context, AppLocalizations.of(context).s0ExitToClose);
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _armed = false);
        });
      },
      child: widget.child,
    );
  }
}
