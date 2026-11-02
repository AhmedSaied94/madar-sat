import 'package:flutter/material.dart';

import '../../core/theme/madar_line.dart';
import '../../core/theme/madar_tokens.dart';

/// A settings or menu row: icon tile, title with optional subtitle, and a trailing value
/// with a chevron, a control, or nothing (ListRow README).
///
/// The whole row is the target, so a row that flips something is a [MadarSwitch] row whose
/// tap goes through [onTap] as well.
class MadarListRow extends StatelessWidget {
  const MadarListRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.danger = false,
  });

  /// The tile's glyph. A row without one (a plain link) starts at the title.
  final IconData? icon;

  final String title;
  final String? subtitle;

  /// A short trailing value («تلقائي», «داكن»); a long choice opens a sheet instead.
  final String? value;

  /// A control in place of the value: a toggle, a bell, an action.
  final Widget? trailing;

  final VoidCallback? onTap;
  final bool showChevron;

  /// The delete-device row: an `error` title and an `error-container` tile.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final foreground = danger ? colors.error : colors.textPrimary;
    final subtitleStyle = MadarText.textCaption.copyWith(color: colors.textTertiary);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: MadarLayout.touchMin),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: MadarSpace.s4,
          vertical: MadarSpace.s1 + MadarSpace.s1 / 2,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: MadarSpace.s8 + MadarSpace.s2,
                height: MadarSpace.s8 + MadarSpace.s2,
                decoration: BoxDecoration(
                  color: danger ? colors.errorContainer : colors.surface2,
                  borderRadius: BorderRadius.circular(MadarRadii.md),
                ),
                child: Icon(
                  icon,
                  size: MadarText.heading2.fontSize,
                  color: danger ? colors.error : colors.textSecondary,
                ),
              ),
              const SizedBox(width: MadarSpace.s3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: MadarText.textBody.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: MadarSpace.s1),
                    Text(subtitle!, style: subtitleStyle),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: MadarSpace.s2),
              Text(value!, style: subtitleStyle.copyWith(color: colors.textSecondary)),
            ],
            if (trailing != null) ...[
              const SizedBox(width: MadarSpace.s2),
              trailing!,
            ],
            if (showChevron) ...[
              const SizedBox(width: MadarSpace.s1),
              Icon(
                // RTL: `chevron_right` mirrors with the text direction and draws pointing
                // left, the way "go" reads (constitution III). `chevron_left` would draw a
                // back arrow.
                Icons.chevron_right,
                size: (MadarText.heading2.fontSize ?? 0),
                color: colors.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );

    return Material(
      color: colors.surface1,
      child: InkWell(
        onTap: onTap,
        child: row,
      ),
    );
  }
}

/// The `surface-1` card that groups rows, with the design's panel radius and hairline.
class MadarListGroup extends StatelessWidget {
  const MadarListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(MadarRadii.xl),
        border: Border.all(color: colors.divider, width: MadarLine.hairline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MadarRadii.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // `.lr + .lr`: the group draws the hairline between rows, never above the first.
            for (final (index, child) in children.indexed) ...[
              if (index != 0)
                Divider(
                  height: MadarLine.hairline,
                  thickness: MadarLine.hairline,
                  color: colors.divider,
                ),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
