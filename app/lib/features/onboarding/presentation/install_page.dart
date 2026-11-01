import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/madar_line.dart';
import '../../../core/theme/madar_tokens.dart';
import '../../../design/components/button.dart';
import '../../../design/components/logo.dart';
import '../../../l10n/app_localizations.dart';

/// S1.5: the three steps that put the PWA on an iPhone's home screen, which is the only
/// place iOS ≥ 16.4 grants Web Push (research R26). Also reachable from S16.
class InstallPage extends StatelessWidget {
  const InstallPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    void close() => context.canPop() ? context.pop() : context.go('/');

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: MadarSpace.s12,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  tooltip: l.cancel,
                  onPressed: close,
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const BrandMark(size: BrandMarkSize.l64),
                        const SizedBox(width: MadarSpace.s3),
                        Expanded(
                          child: Text(
                            l.onbInstallTitle,
                            style: MadarText.heading1.copyWith(
                              color: colors.textPrimary,
                              fontSize: MadarText.heading1.fontSize!,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MadarSpace.s3),
                    Text(
                      l.onbInstallBody,
                      style: MadarText.textLabel.copyWith(
                        color: colors.textSecondary,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: MadarSpace.s6),
                    _Step(
                      number: 1,
                      text: l.onbInstallStep1,
                      illustration: const _ShareBar(),
                    ),
                    const SizedBox(height: MadarSpace.s5),
                    _Step(
                      number: 2,
                      text: l.onbInstallStep2,
                      illustration: const _AddToHomeSheet(),
                    ),
                    const SizedBox(height: MadarSpace.s5),
                    _Step(
                      number: 3,
                      text: l.onbInstallStep3,
                      illustration: const _HomeGrid(),
                    ),
                    const SizedBox(height: MadarSpace.s6),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                MadarSpace.s4,
                MadarSpace.s3,
                MadarSpace.s4,
                MadarSpace.s6,
              ),
              child: Column(
                children: [
                  MadarButton(label: l.gotIt, expanded: true, onPressed: close),
                  const SizedBox(height: MadarSpace.s1),
                  MadarButton(
                    label: l.later,
                    variant: MadarButtonVariant.ghost,
                    expanded: true,
                    onPressed: close,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text, required this.illustration});

  final int number;
  final String text;
  final Widget illustration;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: MadarSpace.s8 - MadarSpace.s1,
          height: MadarSpace.s8 - MadarSpace.s1,
          decoration: BoxDecoration(color: colors.textPrimary, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: MadarText.textStrong.copyWith(color: colors.textOnInverse),
          ),
        ),
        const SizedBox(width: MadarSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: MadarText.textBody.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: MadarSpace.s2),
              illustration,
            ],
          ),
        ),
      ],
    );
  }
}

class _ShareBar extends StatelessWidget {
  const _ShareBar();

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Container(
      height: MadarSpace.s12 + MadarSpace.s4,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(MadarRadii.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final icon in [
            Icons.chevron_left,
            Icons.chevron_right,
            Icons.ios_share,
            Icons.bookmark_border,
            Icons.grid_view,
          ])
            Icon(icon, color: colors.textTertiary),
        ],
      ),
    );
  }
}

class _AddToHomeSheet extends StatelessWidget {
  const _AddToHomeSheet();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    return Container(
      padding: const EdgeInsetsDirectional.all(MadarSpace.s2),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(MadarRadii.lg),
        border: Border.all(color: colors.divider, width: MadarLine.hairline),
      ),
      child: Column(
        children: [
          const _SheetRow(icon: Icons.copy, label: 'نسخ', muted: true),
          _SheetRow(icon: Icons.add_box_outlined, label: l.onbInstallStep2, selected: true),
          const _SheetRow(icon: Icons.star_border, label: 'إضافة إشارة مرجعية', muted: true),
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.label,
    this.selected = false,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Container(
      height: MadarSpace.s8 - MadarSpace.s1,
      margin: const EdgeInsetsDirectional.only(bottom: MadarSpace.s1),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s2),
      decoration: BoxDecoration(
        color: selected ? colors.accentContainer : null,
        borderRadius: BorderRadius.circular(MadarRadii.sm),
        border: selected
            ? Border.all(color: colors.accent, width: 2)
            : null,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: MadarText.textBody.fontSize,
            color: selected
                ? colors.accentText
                : (muted ? colors.textTertiary : colors.textPrimary),
          ),
          const SizedBox(width: MadarSpace.s2),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MadarText.textCaption.copyWith(
                color: selected
                    ? colors.accentText
                    : (muted ? colors.textTertiary : colors.textPrimary),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeGrid extends StatelessWidget {
  const _HomeGrid();

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Container(
      padding: const EdgeInsetsDirectional.all(MadarSpace.s3),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(MadarRadii.lg),
      ),
      child: GridView.count(
        crossAxisCount: 5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: MadarSpace.s2,
        crossAxisSpacing: MadarSpace.s2,
        children: [
          for (var i = 0; i < 10; i++)
            if (i == 7)
              const BrandMark(size: BrandMarkSize.s28)
            else
              Container(
                decoration: BoxDecoration(
                  color: colors.surface3,
                  borderRadius: BorderRadius.circular(MadarRadii.sm),
                ),
              ),
        ],
      ),
    );
  }
}
