import 'package:flutter/material.dart';

import '../../core/theme/madar_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'logo.dart';

/// The bar at the top of every screen: wordmark and search on roots; back, title and up
/// to two actions on details. In RTL the back arrow points right.
class MadarTopBar extends StatelessWidget {
  const MadarTopBar.root({super.key, this.onSearch, this.wordmark})
      : title = null,
        onBack = null,
        actions = const [];

  const MadarTopBar.detail({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
  })  : onSearch = null,
        wordmark = null;

  final String? title;
  final String? wordmark;
  final VoidCallback? onSearch;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final isRoot = title == null;
    return Container(
      height: MadarSpace.s12 + MadarSpace.s2,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          if (!isRoot)
            _BarButton(
              icon: Icons.arrow_back,
              label: l.back,
              onPressed: onBack,
            ),
          if (!isRoot)
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: MadarSpace.s2),
                child: Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MadarText.heading2.copyWith(color: colors.textPrimary),
                ),
              ),
            ),
          if (isRoot) ...[
            MadarWordmark(wordmark: wordmark ?? l.brandMark),
            const Spacer(),
            _BarButton(icon: Icons.search, label: l.search, onPressed: onSearch),
          ],
          if (!isRoot)
            for (final action in actions.take(2)) ...[
              const SizedBox(width: MadarSpace.s1),
              action,
            ],
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.icon, required this.label, this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return IconButton(
      onPressed: onPressed,
      tooltip: label,
      icon: Icon(icon, color: colors.textPrimary),
      constraints: const BoxConstraints(
        minWidth: MadarSpace.s12,
        minHeight: MadarSpace.s12,
      ),
    );
  }
}
