import 'package:flutter/material.dart';

import '../../core/theme/madar_tokens.dart';

/// The onboarding progress dots: the current step is the wide `accent` pill, the steps
/// behind it are `text-tertiary`, the ones ahead `divider-strong` (S1 boards).
class ProgressDots extends StatelessWidget {
  const ProgressDots({
    super.key,
    required this.current,
    required this.count,
    this.semanticsLabel,
  });

  final int current;
  final int count;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: MadarSpace.s1),
            AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              width: i == current ? MadarSpace.s5 : MadarSpace.s2,
              height: MadarSpace.s1,
              decoration: BoxDecoration(
                color: i == current
                    ? colors.accent
                    : (i < current ? colors.textTertiary : colors.dividerStrong),
                borderRadius: BorderRadius.circular(MadarRadii.pill),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
