import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/push_service.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/push_routes.dart';
import 'push_route_listener.dart';

/// Shows a push received with the app open, above the screen, which it pushes down rather than
/// covers (Banner README). Only «عرض» navigates: a goal mid-browse never pulls the fan off their
/// screen (FR-059, R14). One banner at a time, so the newest replaces the one before.
class ForegroundBannerHost extends ConsumerStatefulWidget {
  const ForegroundBannerHost({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<ForegroundBannerHost> createState() => _ForegroundBannerHostState();
}

class _ForegroundBannerHostState extends ConsumerState<ForegroundBannerHost> {
  ForegroundPush? _shown;

  void _dismiss() => setState(() => _shown = null);

  void _view(ForegroundPush push) {
    final route = push.route;
    _dismiss();
    if (route != null) openPushRoute(widget.router, route);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(foregroundPushesProvider, (_, next) {
      final push = next.value;
      if (push != null) setState(() => _shown = push);
    });
    final shown = _shown;
    // One shape with or without a banner: a change of parent would rebuild the app under it,
    // and `BrandSplashGate` would replay the splash on every goal.
    return Column(
      children: [
        if (shown == null)
          const SizedBox.shrink()
        else
          ForegroundBanner(push: shown, onView: () => _view(shown), onDismiss: _dismiss),
        // The banner took the status bar's space, so the screen under it doesn't add it again.
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: shown != null,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

/// The banner itself: bell, title and body, «عرض» when there's somewhere to go, and a close.
class ForegroundBanner extends StatelessWidget {
  const ForegroundBanner({
    super.key,
    required this.push,
    required this.onView,
    required this.onDismiss,
  });

  final ForegroundPush push;
  final VoidCallback onView;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return Material(
      color: colors.surface2,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            MadarSpace.s4,
            MadarSpace.s2,
            MadarSpace.s1,
            MadarSpace.s2,
          ),
          child: Row(
            children: [
              Icon(
                Icons.notifications,
                size: MadarText.textBody.fontSize,
                color: colors.textSecondary,
              ),
              const SizedBox(width: MadarSpace.s2),
              Expanded(
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (push.title.isNotEmpty)
                        Text(
                          push.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MadarText.textLabel.copyWith(color: colors.textPrimary),
                        ),
                      if (push.body.isNotEmpty)
                        Text(
                          push.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: MadarText.textCaption.copyWith(color: colors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ),
              if (push.route != null)
                TextButton(onPressed: onView, child: Text(l.pushBannerView)),
              // No `tooltip`: this sits above the navigator, where there's no overlay for it.
              Semantics(
                button: true,
                label: l.pushBannerDismiss,
                excludeSemantics: true,
                child: IconButton(
                  onPressed: onDismiss,
                  icon: Icon(
                    Icons.close,
                    size: MadarText.textBody.fontSize,
                    color: colors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
