import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/top_bar.dart';

/// A routed destination that has no screen yet. It resolves and renders RTL so deep
/// links and push targets work on D1 (PB §8.4); the real screens arrive on later days.
class StubPage extends StatelessWidget {
  const StubPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            MadarTopBar.detail(
              title: title,
              onBack: context.canPop() ? context.pop : null,
            ),
            Expanded(
              child: Center(
                child: Text(
                  title,
                  style: MadarText.heading2.copyWith(color: colors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
