import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/bidi.dart';
import '../../../../core/format/digits.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/network/generated/models/satellite.dart';
import '../../../../core/settings/settings_providers.dart';
import '../../../../core/theme/madar_tokens.dart';
import '../../../../design/components/skeleton.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../my_satellites/data/my_satellites_provider.dart';
import '../../../my_satellites/domain/default_satellites.dart';
import '../../../system/presentation/system_views.dart';

/// S1.3: the satellites a dish receives. Each tick is written to drift at once, so S2–S5
/// order by the chosen set from then on; skipping keeps O10's Nilesat + Badr default.
///
/// The same widget fills S15's «أقماري» route: [showNote] drops the onboarding footnote.
class SatellitesStep extends ConsumerWidget {
  const SatellitesStep({super.key, this.showNote = true});

  final bool showNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final satellites = ref.watch(satellitesProvider);
    final chosen = ref.watch(settingsProvider).satelliteIds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            MadarSpace.s5,
            MadarSpace.s1,
            MadarSpace.s5,
            MadarSpace.s3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.onbSatellitesTitle,
                style: MadarText.heading2.copyWith(
                  color: colors.textPrimary,
                  fontSize: MadarText.heading1.fontSize!,
                ),
              ),
              const SizedBox(height: MadarSpace.s1),
              Text(
                l.onbSatellitesBody,
                style: MadarText.textLabel.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (satellites) {
            final async when async.hasError && async.value == null => SystemFailureView(
                failure: switch (async.error) {
                  final ApiFailure failure => failure,
                  _ => const ApiFailure(),
                },
                onRetry: () => ref.read(satellitesProvider.notifier).revalidate(),
              ),
            final async => ListView(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface1,
                      borderRadius: BorderRadius.circular(MadarRadii.xl),
                    ),
                    child: Column(
                      children: [
                        for (final satellite
                            in async.value?.data ?? const <Satellite>[])
                          _SatelliteRow(
                            satellite: satellite,
                            selected: chosen.contains(satellite.id),
                            onToggle: () {
                              final next = {...chosen};
                              if (!next.remove(satellite.id)) next.add(satellite.id);
                              ref.read(appSettingsProvider.notifier).setSatellites(next);
                            },
                          ),
                        if (async.value?.data == null) const Skeleton(),
                      ],
                    ),
                  ),
                  if (showNote)
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: MadarSpace.s6,
                        vertical: MadarSpace.s3,
                      ),
                      child: Text(
                        l.onbSatellitesNote,
                        textAlign: TextAlign.center,
                        style: MadarText.textCaption.copyWith(color: colors.textTertiary),
                      ),
                    ),
                ],
              ),
          },
        ),
      ],
    );
  }
}

class _SatelliteRow extends StatelessWidget {
  const _SatelliteRow({
    required this.satellite,
    required this.selected,
    required this.onToggle,
  });

  final Satellite satellite;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final position = satellite.orbitalPosition;
    final popular = MySatellites.defaultSlugs.contains(satellite.slug);
    return Semantics(
      checked: selected,
      label: satellite.nameAr,
      excludeSemantics: true,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          constraints: const BoxConstraints(minHeight: MadarLayout.touchMin + MadarSpace.s2),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: MadarSpace.s3,
            vertical: MadarSpace.s2,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.accentContainer : null,
            border: null,
            borderRadius: BorderRadius.circular(MadarRadii.xl),
          ),
          child: Row(
            children: [
              Container(
                width: MadarSpace.s12,
                height: MadarSpace.s12,
                decoration: BoxDecoration(
                  color: colors.readoutBg,
                  borderRadius: BorderRadius.circular(MadarRadii.md),
                  border: Border.all(color: colors.readoutLine),
                ),
                alignment: Alignment.center,
                child: Text(
                  position == null ? '—' : '${MadarDigits.plain(position.toInt())}°',
                  textDirection: TextDirection.ltr,
                  style: MadarText.readout.copyWith(color: colors.readout),
                ),
              ),
              const SizedBox(width: MadarSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            satellite.nameAr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MadarText.textBody.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (popular) ...[
                          const SizedBox(width: MadarSpace.s1),
                          _PopularChip(label: l.mostUsed),
                        ],
                      ],
                    ),
                    const SizedBox(height: MadarSpace.s1),
                    Row(
                      children: [
                        LtrIsland(
                          satellite.nameEn,
                          style: MadarText.textCaption.copyWith(color: colors.textTertiary),
                        ),
                        Text(
                          ' · ${l.channelCount(satellite.channelCount)}',
                          style: MadarText.textCaption.copyWith(color: colors.textTertiary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MadarSpace.s2),
              _Tick(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopularChip extends StatelessWidget {
  const _PopularChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: MadarSpace.s1,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: colors.surface3,
        borderRadius: BorderRadius.circular(MadarRadii.sm),
      ),
      child: Text(
        label,
        style: MadarText.textMicro.copyWith(color: colors.textSecondary),
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Container(
      width: MadarSpace.s6,
      height: MadarSpace.s6,
      decoration: BoxDecoration(
        color: selected ? colors.accent : null,
        borderRadius: BorderRadius.circular(MadarRadii.sm),
        border: selected ? null : Border.all(color: colors.dividerStrong, width: 1.6),
      ),
      child: selected ? Icon(Icons.check, size: 16, color: colors.onAccent) : null,
    );
  }
}
