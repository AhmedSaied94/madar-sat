import 'package:flutter/material.dart';

import '../../core/l10n/dates.dart';
import '../../core/format/bidi.dart';
import '../../core/theme/madar_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../core/network/generated/models/access.dart';

/// How an entity logo tile is framed; the design fixes one neutral frame for all.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: MadarSpace.s2,
        vertical: MadarSpace.s1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(MadarRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: MadarText.textMicro.fontSize, color: foreground),
            const SizedBox(width: MadarSpace.s1),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MadarText.textMicro.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// `مجانية` with an unlock glyph, or `مشفرة` with a lock. Encrypted is neutral, never an error.
class AccessBadge extends StatelessWidget {
  const AccessBadge({super.key, required this.access, this.provider});

  final Access access;
  final String? provider;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final free = access == Access.free;
    final label = free
        ? l.free
        : provider == null || provider!.isEmpty
            ? l.encrypted
            : '${l.encrypted} · $provider';
    return _Badge(
      label: label,
      foreground: free ? colors.free : colors.encrypted,
      background: free ? colors.freeContainer : colors.encryptedContainer,
      icon: free ? Icons.lock_open_outlined : Icons.lock_outline,
    );
  }
}

/// A satellite name in its neutral frame; Latin names stay LTR islands.
class SatelliteBadge extends StatelessWidget {
  const SatelliteBadge({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return _Badge(
      label: name,
      foreground: colors.textSecondary,
      background: colors.surface3,
      icon: Icons.satellite_alt_outlined,
    );
  }
}

/// `تغيّر مؤخراً · 20 أكتوبر`, paired with a history glyph, never colour alone.
class ChangedBadge extends StatelessWidget {
  const ChangedBadge({super.key, required this.changedAt});

  final DateTime changedAt;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return _Badge(
      label: '${l.changedRecently} · ${MadarDates.dayMonth(l, changedAt.toLocal())}',
      foreground: colors.changed,
      background: colors.changedContainer,
      icon: Icons.history,
    );
  }
}

/// A category pill: رياضة or ترفيه.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.sports});

  final bool sports;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return _Badge(
      label: sports ? l.categorySports : l.categoryEntertainment,
      foreground: sports ? colors.sports : colors.entertainment,
      background: sports ? colors.sportsContainer : colors.entertainmentContainer,
    );
  }
}

/// The `+N` count pill beside a channel line.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, this.label});

  final int count;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return _Badge(
      label: label ?? AppLocalizations.of(context).channelsMore(count),
      foreground: colors.textSecondary,
      background: colors.surface3,
    );
  }
}

/// A Latin name as an isolated LTR island, or Arabic text as-is.
class EntityName extends StatelessWidget {
  const EntityName(this.name, {super.key, this.style});

  final String name;
  final TextStyle? style;

  static final RegExp _arabic = RegExp(r'[\u0600-\u06FF]');

  @override
  Widget build(BuildContext context) {
    final effective = style ?? MadarText.textStrong.copyWith(color: context.madarColors.textPrimary);
    if (_arabic.hasMatch(name)) {
      return Text(name, style: effective, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return LtrIsland(name, style: effective);
  }
}
