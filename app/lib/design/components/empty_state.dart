import 'package:flutter/material.dart';

import '../../core/theme/madar_line.dart';
import '../../core/theme/madar_tokens.dart';

/// What the empty screen is saying: nothing to list, a failed load, or all clear.
enum EmptyStateKind { empty, error, allClear }

/// What a screen shows when there is nothing to list or loading failed: the orbit-ring
/// illustration, a title, one line of help and at most one action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.kind = EmptyStateKind.empty,
    required this.title,
    this.body,
    this.action,
  });

  final EmptyStateKind kind;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final (foreground, background, glyph) = switch (kind) {
      EmptyStateKind.empty => (colors.textTertiary, colors.surface2, Icons.manage_search),
      EmptyStateKind.error => (colors.error, colors.errorContainer, Icons.error_outline),
      EmptyStateKind.allClear => (colors.free, colors.freeContainer, Icons.check_circle_outline),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MadarSpace.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              painter: _OrbitRingsPainter(ring: colors.dividerStrong),
              child: Container(
                width: MadarSpace.s12 + MadarSpace.s8,
                height: MadarSpace.s12 + MadarSpace.s8,
                decoration: BoxDecoration(color: background, shape: BoxShape.circle),
                child: Icon(glyph, color: foreground, size: MadarSpace.s6),
              ),
            ),
            const SizedBox(height: MadarSpace.s4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: MadarText.heading2.copyWith(color: colors.textPrimary),
            ),
            if (body != null) ...[
              const SizedBox(height: MadarSpace.s2),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: MadarText.textBody.copyWith(color: colors.textSecondary),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: MadarSpace.s4),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _OrbitRingsPainter extends CustomPainter {
  const _OrbitRingsPainter({required this.ring});

  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = MadarLine.hairline
      ..color = ring;
    for (final factor in [1.0, 1.35, 1.7]) {
      canvas.drawCircle(center, size.shortestSide * 0.5 * factor, paint);
    }
    canvas.drawCircle(
      center + Offset(size.width * 0.42, -size.height * 0.38),
      size.shortestSide * 0.035,
      Paint()..color = ring,
    );
  }

  @override
  bool shouldRepaint(_OrbitRingsPainter oldDelegate) => oldDelegate.ring != ring;
}
