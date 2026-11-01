import 'package:flutter/material.dart';

import '../../core/theme/madar_line.dart';
import '../../core/theme/madar_tokens.dart';

/// The toggle of a settings row: `surface-3` track off, `accent` on with an `on-accent`
/// knob (FormControls README). The row's label is the target, so the control itself is
/// 46×28 with a 48 dp hit box around it.
class MadarSwitch extends StatelessWidget {
  const MadarSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: label,
      onTap: enabled ? () => onChanged?.call(!value) : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? () => onChanged?.call(!value) : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: MadarLayout.touchMin,
          height: MadarLayout.touchMin,
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                width: MadarSpace.s12,
                height: MadarSpace.s6,
                decoration: BoxDecoration(
                  color: value ? colors.accent : colors.surface3,
                  borderRadius: BorderRadius.circular(MadarRadii.pill),
                  border: value
                      ? null
                      : Border.all(color: colors.dividerStrong, width: MadarLine.hairline),
                ),
                child: Align(
                  alignment: value
                      ? AlignmentDirectional.centerStart
                      : AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s1),
                    child: Container(
                      width: MadarSpace.s5,
                      height: MadarSpace.s5,
                      decoration: BoxDecoration(
                        color: value ? colors.onAccent : colors.textTertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A radio in a list of exclusive choices: `divider-strong` outline off, `accent` ring and
/// dot on. The row that holds it is the target.
class MadarRadio extends StatelessWidget {
  const MadarRadio({
    super.key,
    required this.selected,
    required this.onTap,
    required this.label,
    this.enabled = true,
  });

  final bool selected;
  final VoidCallback? onTap;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      label: label,
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: MadarLayout.touchMin,
          height: MadarLayout.touchMin,
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: Container(
                width: MadarSpace.s6,
                height: MadarSpace.s6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? colors.accentText : colors.dividerStrong,
                    width: selected ? 2 : MadarLine.hairline * 1.6,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: MadarSpace.s2,
                          height: MadarSpace.s2,
                          decoration: BoxDecoration(
                            color: colors.accentText,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A square checkbox: `divider-strong` outline off, `accent` fill with an `on-accent`
/// check on.
class MadarCheckbox extends StatelessWidget {
  const MadarCheckbox({
    super.key,
    required this.checked,
    required this.onChanged,
    required this.label,
    this.enabled = true,
  });

  final bool checked;
  final ValueChanged<bool>? onChanged;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Semantics(
      checked: checked,
      enabled: enabled,
      label: label,
      onTap: enabled ? () => onChanged?.call(!checked) : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? () => onChanged?.call(!checked) : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: MadarLayout.touchMin,
          height: MadarLayout.touchMin,
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: Container(
                width: MadarSpace.s6,
                height: MadarSpace.s6,
                decoration: BoxDecoration(
                  color: checked ? colors.accent : null,
                  borderRadius: BorderRadius.circular(MadarRadii.sm),
                  border: checked
                      ? null
                      : Border.all(color: colors.dividerStrong, width: MadarLine.hairline * 1.6),
                ),
                child: checked
                    ? Icon(
                        Icons.check,
                        size: MadarText.textBody.fontSize,
                        color: colors.onAccent,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
