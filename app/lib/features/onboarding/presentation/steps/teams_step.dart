import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/media_image.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/theme/madar_tokens.dart';
import '../../../../design/components/logo.dart';
import '../../../../design/components/search_field.dart';
import '../../../../design/components/skeleton.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../follows/data/follows_repository.dart';
import '../../../follows/domain/follow_set.dart';
import '../../../system/presentation/system_views.dart';
import '../../../teams/data/team_search_provider.dart';
import '../../../teams/domain/team_groups.dart';

/// S1.2: search D1's teams, group them by competition (popular first) and collect the chosen
/// ones in a tray. Every toggle writes drift at once, so a quit keeps the choice.
class TeamsStep extends ConsumerStatefulWidget {
  const TeamsStep({super.key});

  @override
  ConsumerState<TeamsStep> createState() => _TeamsStepState();
}

class _TeamsStepState extends ConsumerState<TeamsStep> {
  String _query = '';
  final Map<int, String> _chosenNames = {};

  void _onQuery(String value) {
    final trimmed = value.trim();
    if (trimmed == _query) return;
    setState(() => _query = trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    final follows = ref.watch(followSetValueProvider);
    final results = _query.length >= 2 ? ref.watch(teamSearchProvider(_query)) : null;

    for (final group in results?.value == null ? const <TeamGroup>[] : groupTeams(results!.value!)) {
      for (final team in group.teams) {
        _chosenNames.putIfAbsent(team.id, () => team.name);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            MadarSpace.s5,
            MadarSpace.s1,
            MadarSpace.s5,
            MadarSpace.s2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.onbTeamsTitle,
                style: MadarText.heading1.copyWith(
                  color: colors.textPrimary,
                  fontSize: MadarText.heading1.fontSize!,
                ),
              ),
              const SizedBox(height: MadarSpace.s1),
              Text(
                l.onbTeamsBody,
                style: MadarText.textLabel.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
          child: SearchField(hint: l.onbSearchTeam, onChanged: _onQuery),
        ),
        const SizedBox(height: MadarSpace.s2),
        Expanded(
          child: switch (results) {
            null => _Prompt(text: l.onbSearchTeam),
            // A failed search says so at once, with «إعادة المحاولة» asking again; the
            // check comes before the skeleton, so a retry never looks like a hang
            // (M-T045-3).
            final async when async.hasError => SystemFailureView(
                failure: async.error is ApiFailure
                    ? async.error! as ApiFailure
                    : const ApiFailure(),
                retrying: async.isLoading,
                onRetry: () => ref.invalidate(teamSearchProvider(_query)),
              ),
            final async when async.isLoading && async.value == null => const Skeleton(),
            final async => _Results(
                groups: groupTeams(async.value ?? const []),
                chosen: follows.teams,
                onToggle: (id, name) {
                  _chosenNames[id] = name;
                  unawaited(
                    ref.read(followsRepositoryProvider).set(
                          FollowKind.team,
                          id,
                          follow: !follows.teams.contains(id),
                        ),
                  );
                },
              ),
          },
        ),
        if (follows.teams.isNotEmpty) _Tray(
          names: [
            for (final id in follows.teams)
              if (_chosenNames[id] != null) (id: id, name: _chosenNames[id]!),
          ],
          onRemove: (id) => unawaited(
            ref.read(followsRepositoryProvider).set(FollowKind.team, id, follow: false),
          ),
        ),
      ],
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MadarSpace.s6),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: MadarText.textBody.copyWith(color: colors.textTertiary),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.groups, required this.chosen, required this.onToggle});

  final List<TeamGroup> groups;
  final Set<int> chosen;
  final void Function(int id, String name) onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.madarColors;
    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(MadarSpace.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.onbTeamsEmpty,
                textAlign: TextAlign.center,
                style: MadarText.textStrong.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: MadarSpace.s1),
              Text(
                l.onbTeamsEmptyBody,
                textAlign: TextAlign.center,
                style: MadarText.textBody.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsetsDirectional.only(bottom: MadarSpace.s4),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                MadarSpace.s5,
                MadarSpace.s4,
                MadarSpace.s5,
                MadarSpace.s2,
              ),
              child: Row(
                children: [
                  Icon(Icons.emoji_events_outlined, size: MadarText.textLabel.fontSize, color: colors.textSecondary),
                  const SizedBox(width: MadarSpace.s2),
                  Expanded(
                    child: Text(
                      group.competition,
                      style: MadarText.textLabel.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
              child: Wrap(
                spacing: MadarSpace.s2,
                runSpacing: MadarSpace.s2,
                children: [
                  for (final team in group.teams)
                    _TeamTile(
                      name: team.name,
                      logo: team.logo,
                      selected: chosen.contains(team.id),
                      onTap: () => onToggle(team.id, team.name),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({
    required this.name,
    required this.logo,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String? logo;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.accentContainer : colors.surface1,
        borderRadius: BorderRadius.circular(MadarRadii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(MadarRadii.lg),
          onTap: onTap,
          child: Container(
            width: MadarLayout.touchMin * 2,
            constraints: const BoxConstraints(minHeight: MadarLayout.touchMin * 2),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: MadarSpace.s1,
              vertical: MadarSpace.s2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MadarRadii.lg),
              border: Border.all(
                color: selected ? colors.accent : colors.divider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TeamCrest(name: name, logo: mediaImage(context, logo), size: MadarSpace.s12),
                const SizedBox(height: MadarSpace.s1),
                Text(
                  name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: MadarText.textCaption.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The chosen teams, above the footer button.
class _Tray extends StatelessWidget {
  const _Tray({required this.names, required this.onRemove});

  final List<({int id, String name})> names;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.madarColors;
    return SizedBox(
      height: MadarSpace.s12,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
        itemCount: names.length,
        separatorBuilder: (_, _) => const SizedBox(width: MadarSpace.s2),
        itemBuilder: (context, index) {
          final entry = names[index];
          return Center(
            child: ActionChip(
              backgroundColor: colors.surface2,
              side: BorderSide.none,
              shape: const StadiumBorder(),
              avatar: TeamCrest(name: entry.name, size: MadarSpace.s6),
              label: Text(
                entry.name,
                style: MadarText.textCaption.copyWith(color: colors.textPrimary),
              ),
              onPressed: () => onRemove(entry.id),
            ),
          );
        },
      ),
    );
  }
}
