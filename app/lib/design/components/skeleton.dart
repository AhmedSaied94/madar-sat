import 'package:flutter/material.dart';

import '../../core/theme/madar_tokens.dart';

/// The S2 first-load skeleton: [groups] groups of [rowsPerGroup] rows.
///
/// It is static when the OS asks for reduced motion (constitution IV): no shimmer.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.groups = 3, this.rowsPerGroup = 3});

  final int groups;
  final int rowsPerGroup;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(_controller),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          for (var group = 0; group < widget.groups; group++) ...[
            if (group > 0) const SizedBox(height: MadarSpace.s5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MadarSpace.s4),
              child: _Block(
                height: MadarSpace.s3,
                widthFactor: 0.45,
                color: colors.surface3,
              ),
            ),
            const SizedBox(height: MadarSpace.s2),
            for (var row = 0; row < widget.rowsPerGroup; row++)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: MadarSpace.s4,
                  vertical: MadarSpace.s1,
                ),
                child: _Block(
                  height: MadarSpace.s5 * 2,
                  widthFactor: 1,
                  color: colors.surface2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.height, required this.widthFactor, required this.color});

  final double height;
  final double widthFactor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(MadarRadii.lg),
        ),
      ),
    );
  }
}
