import 'package:flutter/material.dart';

import '../../core/theme/madar_line.dart';
import '../../core/theme/madar_tokens.dart';

/// The five emphasis levels of the design system's button (Button README).
enum MadarButtonVariant { primary, secondary, outline, ghost, danger }

/// The three sizes: 48 dp (default), 40 dp (`sm`) and 32 dp (`xs`, inside rows). Every size
/// keeps a 48 dp target through the surrounding padding or the minimum hit box.
enum MadarButtonSize { regular, small, extraSmall }

/// The app's button: one primary per screen, the verb as its label, a busy spinner in place
/// of the label while an action runs.
class MadarButton extends StatelessWidget {
  const MadarButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = MadarButtonVariant.primary,
    this.size = MadarButtonSize.regular,
    this.icon,
    this.trailingIcon,
    this.busy = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final MadarButtonVariant variant;
  final MadarButtonSize size;
  final IconData? icon;

  /// After the label, at the row's end: «التالي» points forward on S1.2–S1.4. In RTL an
  /// `arrow_forward` with `matchTextDirection` draws pointing left, the way forward reads.
  final IconData? trailingIcon;

  /// The action is out: the spinner replaces the icon and the label stays, in the present
  /// tense («جارٍ الحفظ»).
  final bool busy;

  /// Fills the width it is given (the onboarding footer and the dialog's action).
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final (background, foreground, border) = switch (variant) {
      MadarButtonVariant.primary => (colors.accent, colors.onAccent, null),
      MadarButtonVariant.secondary => (colors.surface2, colors.textPrimary, null),
      MadarButtonVariant.outline => (null, colors.textPrimary, colors.dividerStrong),
      MadarButtonVariant.ghost => (null, colors.accentText, null),
      MadarButtonVariant.danger => (colors.errorContainer, colors.error, null),
    };
    final height = switch (size) {
      MadarButtonSize.regular => MadarLayout.touchMin,
      MadarButtonSize.small => MadarSpace.s8 + MadarSpace.s2,
      MadarButtonSize.extraSmall => MadarSpace.s8,
    };
    final iconSize = (MadarText.textBody.fontSize ?? 0) + 4;
    final disabled = onPressed == null;
    final content = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                const SizedBox(
                  width: MadarSpace.s4,
                  height: MadarSpace.s4,
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(width: MadarSpace.s2),
              ] else if (icon != null) ...[
                Icon(icon, size: iconSize),
                const SizedBox(width: MadarSpace.s2),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MadarText.textStrong.copyWith(
                    color: disabled ? colors.textDisabled : foreground,
                    fontSize: size == MadarButtonSize.extraSmall
                        ? MadarText.textCaption.fontSize
                        : MadarText.textBody.fontSize,
                  ),
                ),
              ),
              if (trailingIcon != null && !busy) ...[
                const SizedBox(width: MadarSpace.s2),
                Icon(trailingIcon, size: iconSize, color: disabled ? colors.textDisabled : foreground),
              ],
            ],
          );

    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      // `excludeSemantics` drops the InkWell's tap, so the node carries its own.
      onTap: busy ? null : onPressed,
      excludeSemantics: true,
      child: Material(
        color: disabled ? colors.surface2 : (background ?? colors.surface1),
        borderRadius: BorderRadius.circular(
          size == MadarButtonSize.regular ? MadarRadii.lg : MadarRadii.md,
        ),
        child: InkWell(
          onTap: busy ? null : onPressed,
          borderRadius: BorderRadius.circular(
            size == MadarButtonSize.regular ? MadarRadii.lg : MadarRadii.md,
          ),
          // The tap area is at least 48 dp in both directions whatever the visual size is:
          // `sm` draws 40 and `xs` 32, and both still take a 48 dp hit (constitution IV).
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: MadarLayout.touchMin,
              minHeight: MadarLayout.touchMin,
            ),
            child: Center(
              child: Container(
                height: height,
                padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    size == MadarButtonSize.regular ? MadarRadii.lg : MadarRadii.md,
                  ),
                  border: border == null
                      ? null
                      : Border.all(color: border, width: MadarLine.hairline),
                ),
                child: Center(child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// FollowButton: «تابع» with an outline star, «تتابعه» with the star filled and the
/// `accent-container` pill (Button README). Used on teams, competitions and matches.
class FollowButton extends StatelessWidget {
  const FollowButton({
    super.key,
    required this.following,
    required this.onPressed,
    required this.label,
    required this.followingLabel,
    this.busy = false,
  });

  final bool following;
  final VoidCallback? onPressed;
  final String label;
  final String followingLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final foreground = following ? colors.accentText : colors.textPrimary;
    return Semantics(
      button: true,
      selected: following,
      label: following ? followingLabel : label,
      excludeSemantics: true,
      // The pill draws 28 dp; the pill sits inside a 48 dp target (constitution IV).
      child: Material(
        // A transparent surface only so the ink has something to paint on: the pill below
        // draws its own fill, and the box outside it is the 48 dp target.
        type: MaterialType.transparency,
        child: InkWell(
          onTap: busy ? null : onPressed,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: MadarLayout.touchMin,
              minHeight: MadarLayout.touchMin,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Container(
                height: MadarSpace.s8 - MadarSpace.s1,
                padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s3),
                decoration: BoxDecoration(
                  color: following ? colors.accentContainer : colors.surface1,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(MadarRadii.pill),
                  border: following
                      ? null
                      : Border.all(color: colors.dividerStrong, width: MadarLine.hairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      following ? Icons.star : Icons.star_border,
                      size: (MadarText.textLabel.fontSize ?? 0) + 3,
                      color: foreground,
                    ),
                    const SizedBox(width: MadarSpace.s1),
                    Text(
                      following ? followingLabel : label,
                      style: MadarText.textLabel.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// BellButton: the reminder toggle of a team, competition or channel. Off is hollow, on is
/// filled in `accent-text`, muted is hollow again with the secondary tone.
class BellButton extends StatelessWidget {
  const BellButton({
    super.key,
    required this.on,
    required this.onPressed,
    required this.label,
    this.muted = false,
  });

  final bool on;
  final VoidCallback? onPressed;
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    final filled = on && !muted;
    return Semantics(
      button: true,
      toggled: on,
      label: label,
      excludeSemantics: true,
      child: IconButton(
        onPressed: onPressed,
        tooltip: label,
        constraints: const BoxConstraints(
          minWidth: MadarLayout.touchMin,
          minHeight: MadarLayout.touchMin,
        ),
        icon: Container(
          width: MadarSpace.s8 - MadarSpace.s1,
          height: MadarSpace.s8 - MadarSpace.s1,
          decoration: BoxDecoration(
            color: filled ? colors.accentContainer : null,
            shape: BoxShape.circle,
          ),
          child: Icon(
            filled ? Icons.notifications : Icons.notifications_none,
            size: (MadarText.textStrong.fontSize ?? 0) + 4,
            color: filled ? colors.accentText : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
