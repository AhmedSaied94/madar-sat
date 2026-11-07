import 'package:flutter/material.dart';

import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/list_row.dart';

/// A group's small title in S15: «الإشعارات», «أقماري».
class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          MadarSpace.s6,
          MadarSpace.s5,
          MadarSpace.s6,
          MadarSpace.s2,
        ),
        child: Text(
          title,
          style: MadarText.textCaption.copyWith(
            color: context.madarColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

/// A group's rows on their card.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
        child: MadarListGroup(children: children),
      );
}
