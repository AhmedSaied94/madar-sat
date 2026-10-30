import 'package:flutter/material.dart';

import '../../core/theme/madar_line.dart';
import '../../core/theme/madar_tokens.dart';
import '../../l10n/app_localizations.dart';

/// The focus ring is a little heavier than a hairline (the design draws 1.5 px).
const double _ring = MadarLine.hairline * 2;

/// The app's search field: `surface-2`, 48 dp, a clear button once there is text
/// (FormControls README). Results update as you type after 2 characters; that is the
/// screen's rule, so this reports every change.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.dense = false,
  });

  final String hint;

  /// Owned by the caller when given; the field never disposes it.
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  /// The 40 dp variant for a field inside another surface.
  final bool dense;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  TextEditingController? _owned;
  final FocusNode _focus = FocusNode();

  TextEditingController get _controller => widget.controller ?? (_owned ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    _focus.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _owned)?.removeListener(_rebuild);
      _controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _owned?.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final focused = _focus.hasFocus;
    return Semantics(
      container: true,
      label: widget.hint,
      child: Container(
        height: widget.dense ? MadarSpace.s8 + MadarSpace.s2 : MadarLayout.touchMin,
        padding: const EdgeInsetsDirectional.only(start: MadarSpace.s3),
        decoration: BoxDecoration(
          color: focused ? colors.surface1 : colors.surface2,
          borderRadius: BorderRadius.circular(MadarRadii.lg),
          border: focused ? Border.all(color: colors.focusRing, width: _ring) : null,
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: MadarText.textBody.fontSize, color: colors.textTertiary),
            const SizedBox(width: MadarSpace.s2),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                textInputAction: TextInputAction.search,
                style: MadarText.textBody.copyWith(color: colors.textPrimary),
                cursorColor: colors.accentText,
                decoration: InputDecoration.collapsed(
                  hintText: widget.hint,
                  hintStyle: MadarText.textBody.copyWith(color: colors.textTertiary),
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                onPressed: _clear,
                tooltip: l.clearSearch,
                icon: Icon(Icons.close, size: MadarText.textBody.fontSize, color: colors.textTertiary),
                constraints: const BoxConstraints(
                  minWidth: MadarLayout.touchMin,
                  minHeight: MadarLayout.touchMin,
                ),
              )
            else
              const SizedBox(width: MadarSpace.s3),
          ],
        ),
      ),
    );
  }
}
