import { useEffect, useMemo, useState, type ReactElement } from 'react';
import { useBlocker, useNavigate, useParams } from 'react-router-dom';

import { useCreateMatch, useGetMatch, useListCommentators, useListCompetitions, usePatchMatch } from '../../api/generated/admin';
import type { AdminMatch, MatchCreate, MatchPatch, Status } from '../../api/generated/admin.schemas';
import { patchMatchBody } from '../../api/generated/admin.zod';
import { ApiError, getEntityEtag } from '../../api/http';
import { Button } from '../../components/Button/Button';
import { ConflictDialog, type ConflictChange } from '../../components/ConfirmDialog/ConflictDialog';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { useToast } from '../../components/Toast/Toast';
import { EditorSections } from './editor/FieldsSection';
import { BroadcastSlots } from './editor/BroadcastSlots';
import { ChannelsSection } from './editor/ChannelsSection';
import { StatusSection } from './editor/StatusSection';
import { cairoWallTimeToUtc, formatCairoTime, utcToCairoWallTime } from '../../lib/cairoTime';
import { copyForErrorCode, editor as copy, toast as toastCopy } from '../../i18n/ar';

// A4 (admin board "Match editor"): one form over Orval's `patchMatchBody`, so what the API accepts is
// what the form checks. A save sends only the sections the editor changed, under the match's `If-Match`;
// a 409 opens ConflictDialog with what changed and can reload the other side's version.

export interface EditorState {
  /** The Cairo date and time the editor typed; together they make the stored UTC instant. */
  date: string;
  time: string;
  timeTbd: boolean;
  competitionId: string;
  stage: string;
  stadium: string;
  home: { teamId: number | null; name: string };
  away: { teamId: number | null; name: string };
  statusMode: 'auto' | Status;
  scoreHome: string;
  scoreAway: string;
  homePen: string;
  awayPen: string;
  channels: EditorChannel[];
  broadcasts: EditorBroadcast[];
}

export interface EditorChannel {
  channelId: number;
  name: string;
  displayName: string | null;
  source: string;
  satellite: string | null;
  frequency: string | null;
  isHidden: boolean;
  hiddenByName: boolean;
  commentatorId: number | null;
  commentator2Id: number | null;
}

export interface EditorBroadcast {
  slot: 1 | 2;
  label: string;
  commentatorId: number | null;
}

const SCORE_REQUIRED: readonly Status[] = ['live', 'halftime', 'extra_time', 'penalties', 'finished'];
const SCORE_OPTIONAL: readonly Status[] = ['abandoned'];
const PENALTIES_ALLOWED: readonly Status[] = ['penalties', 'finished'];

export const scoreAllowed = (status: Status): boolean =>
  SCORE_REQUIRED.includes(status) || SCORE_OPTIONAL.includes(status);
export const scoreRequired = (status: Status): boolean => SCORE_REQUIRED.includes(status);
export const penaltiesAllowed = (status: Status): boolean => PENALTIES_ALLOWED.includes(status);

function fromMatch(match: AdminMatch): EditorState {
  const wall = match.kickoff_at ? utcToCairoWallTime(match.kickoff_at) : '';
  return {
    date: wall ? wall.slice(0, 10) : match.match_date,
    time: wall ? wall.slice(11, 16) : '',
    timeTbd: match.time_tbd,
    competitionId: String(match.competition_id ?? ''),
    stage: match.competition_stage ?? '',
    stadium: match.stadium ?? '',
    home: { teamId: match.home.team_id, name: match.home.name },
    away: { teamId: match.away.team_id, name: match.away.name },
    statusMode: match.status.status_source === 'manual' ? match.status.status : 'auto',
    scoreHome: match.status.score ? String(match.status.score.home) : '',
    scoreAway: match.status.score ? String(match.status.score.away) : '',
    homePen: match.status.score?.home_pen != null ? String(match.status.score.home_pen) : '',
    awayPen: match.status.score?.away_pen != null ? String(match.status.score.away_pen) : '',
    channels: match.channels.map((channel) => ({
      channelId: channel.channel_id,
      name: channel.name,
      displayName: channel.display_name,
      source: channel.source,
      satellite: channel.satellite?.name_en ?? null,
      frequency: channel.frequency ? `${channel.frequency.mhz} ${channel.frequency.pol}` : null,
      isHidden: channel.is_hidden,
      hiddenByName: channel.hidden_by_name,
      commentatorId: channel.commentator_id,
      commentator2Id: channel.commentator2_id,
    })),
    broadcasts: match.broadcasts.map((broadcast) => ({
      slot: broadcast.slot === 2 ? 2 : 1,
      label: broadcast.label,
      commentatorId: broadcast.commentator_id,
    })),
  };
}

const emptyState = (): EditorState => ({
  date: '',
  time: '',
  timeTbd: false,
  competitionId: '',
  stage: '',
  stadium: '',
  home: { teamId: null, name: '' },
  away: { teamId: null, name: '' },
  statusMode: 'auto',
  scoreHome: '',
  scoreAway: '',
  homePen: '',
  awayPen: '',
  channels: [],
  broadcasts: [],
});

/** The patch for the sections that changed, or an empty object when nothing did. */
export function buildPatch(current: EditorState, original: EditorState): MatchPatch {
  const patch: MatchPatch = {};
  const fields: NonNullable<MatchPatch['fields']> = {};

  if (current.date !== original.date || current.time !== original.time || current.timeTbd !== original.timeTbd) {
    fields.time_tbd = current.timeTbd;
    const wall = current.date && current.time ? `${current.date}T${current.time}` : '';
    fields.kickoff_at = current.timeTbd || wall === '' ? null : cairoWallTimeToUtc(wall);
  }
  if (current.competitionId !== original.competitionId) {
    fields.competition_id = current.competitionId === '' ? null : Number(current.competitionId);
  }
  if (current.stage !== original.stage) fields.competition_stage = current.stage || null;
  if (current.stadium !== original.stadium) fields.stadium = current.stadium || null;
  if (current.home.teamId !== original.home.teamId || current.home.name !== original.home.name) {
    fields.home = current.home.teamId === null ? { name: current.home.name } : { team_id: current.home.teamId };
  }
  if (current.away.teamId !== original.away.teamId || current.away.name !== original.away.name) {
    fields.away = current.away.teamId === null ? { name: current.away.name } : { team_id: current.away.teamId };
  }
  if (current.statusMode !== original.statusMode || current.scoreHome !== original.scoreHome || current.scoreAway !== original.scoreAway) {
    if (current.statusMode === 'auto') {
      patch.status = { clear: true };
    } else {
      const set: NonNullable<NonNullable<MatchPatch['status']>['set']> = { status: current.statusMode };
      if (scoreAllowed(current.statusMode)) {
        set.score = {
          home: Number(current.scoreHome || 0),
          away: Number(current.scoreAway || 0),
          home_pen: penaltiesAllowed(current.statusMode) && current.homePen !== '' ? Number(current.homePen) : null,
          away_pen: penaltiesAllowed(current.statusMode) && current.awayPen !== '' ? Number(current.awayPen) : null,
        };
      }
      patch.status = { set };
    }
  }
  if (Object.keys(fields).length > 0) patch.fields = fields;

  const channelsChanged =
    current.channels.length !== original.channels.length ||
    current.channels.some((channel, index) => {
      const before = original.channels[index];
      return (
        !before ||
        before.channelId !== channel.channelId ||
        before.isHidden !== channel.isHidden ||
        before.commentatorId !== channel.commentatorId ||
        before.commentator2Id !== channel.commentator2Id
      );
    });
  if (channelsChanged) {
    patch.channels = current.channels.map((channel) => ({
      channel_id: channel.channelId,
      is_hidden: channel.isHidden,
      commentator_id: channel.commentatorId,
      commentator2_id: channel.commentator2Id,
    }));
  }

  const broadcastsChanged = current.broadcasts.some((broadcast) => {
    const before = original.broadcasts.find((candidate) => candidate.slot === broadcast.slot);
    return (
      (broadcast.label !== '' && (!before || before.label !== broadcast.label)) ||
      (before && before.commentatorId !== broadcast.commentatorId) ||
      (broadcast.label === '' && before !== undefined)
    );
  });
  if (broadcastsChanged) {
    patch.broadcasts = current.broadcasts
      .filter((broadcast) => broadcast.label !== '')
      .map((broadcast) => ({ slot: broadcast.slot, label: broadcast.label, commentator_id: broadcast.commentatorId }));
  }

  return patch;
}

/** The diff the conflict dialog shows: the sections that would have been written, before and after. */
export function patchChanges(current: EditorState, original: EditorState): ConflictChange[] {
  const changes: ConflictChange[] = [];
  if (current.date !== original.date || current.time !== original.time) {
    const wall = (state: EditorState): string | null =>
      state.date && state.time ? formatCairoTime(cairoWallTimeToUtc(`${state.date}T${state.time}`)) : null;
    changes.push({ field: 'kickoff_at', label: copy.time, before: wall(original), after: wall(current) });
  }
  if (current.stage !== original.stage) {
    changes.push({ field: 'competition_stage', label: copy.stage, before: original.stage || null, after: current.stage || null });
  }
  if (current.stadium !== original.stadium) {
    changes.push({ field: 'stadium', label: copy.stadium, before: original.stadium || null, after: current.stadium || null });
  }
  if (current.channels.length !== original.channels.length) {
    changes.push({
      field: 'channels',
      label: copy.channels,
      before: String(original.channels.length),
      after: String(current.channels.length),
    });
  }
  return changes;
}

export function MatchEditor(): ReactElement {
  const { id } = useParams<{ id: string }>();
  const matchId = id === undefined ? null : Number(id);
  const navigate = useNavigate();
  const toast = useToast();
  const [etag, setEtag] = useState<string | null>(null);
  const [initial, setInitial] = useState<EditorState | null>(null);
  const [state, setState] = useState<EditorState>(emptyState);
  const [conflict, setConflict] = useState<{ changedBy: { kind: 'admin' | 'source'; name: string; at: string }; changes: ConflictChange[] } | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);

  const match = useGetMatch(matchId ?? 0, { query: { enabled: matchId !== null } });
  const create = useCreateMatch();
  // `If-Match` rides on the mutation's request options: the version the editor loaded.
  const patch = usePatchMatch({ request: { headers: etag ? { 'If-Match': etag } : {} } });
  const competitions = useListCompetitions();
  const commentators = useListCommentators({ limit: 100 });

  useEffect(() => {
    if (!match.data?.data) return;
    const loaded = fromMatch(match.data.data);
    setInitial(loaded);
    setState(loaded);
    if (matchId !== null) {
      void getEntityEtag(`/admin/api/matches/${matchId}`)
        .then(setEtag)
        .catch(() => setEtag(null));
    }
  }, [match.data, matchId]);

  // The unsaved guard (research R24): the router blocks the leave, and a reload asks the browser.
  const dirty = initial !== null && JSON.stringify(buildPatch(state, initial)) !== '{}';
  const blocker = useBlocker(({ currentLocation, nextLocation }) => dirty && currentLocation.pathname !== nextLocation.pathname);

  useEffect(() => {
    if (!dirty) return;
    const onBeforeUnload = (event: BeforeUnloadEvent): void => {
      event.preventDefault();
    };
    window.addEventListener('beforeunload', onBeforeUnload);
    return () => window.removeEventListener('beforeunload', onBeforeUnload);
  }, [dirty]);

  const competitors = useMemo(
    () => (competitions.data?.data ?? []).map((competition) => ({ id: competition.id, name: competition.name })),
    [competitions.data],
  );
  const commentatorOptions = useMemo(
    () => (commentators.data?.data ?? []).map((person) => ({ id: person.id, name: person.name })),
    [commentators.data],
  );

  async function save(): Promise<void> {
    if (initial === null) return;
    const built = buildPatch(state, initial);
    if (Object.keys(built).length === 0) return;
    const parsed = patchMatchBody.safeParse(built);
    if (!parsed.success) {
      setSaveError(copyForErrorCode('validation_error'));
      return;
    }

    try {
      if (matchId === null) {
        await create.mutateAsync({
          data: {
            ...parsed.data,
            match_date: state.date,
            home: state.home.teamId === null ? { name: state.home.name } : { team_id: state.home.teamId },
            away: state.away.teamId === null ? { name: state.away.name } : { team_id: state.away.teamId },
          } as MatchCreate,
        });
      } else {
        await patch.mutateAsync({ matchId, data: parsed.data as MatchPatch });
      }
      setInitial(state);
      setSaveError(null);
      toast.show({ kind: 'success', title: toastCopy.saved });
    } catch (error) {
      const failure = error as ApiError;
      setSaveError(copyForErrorCode(failure.code));
      if (failure.code === 'edit_conflict') {
        const meta = failure.meta as { changed_by?: { kind?: 'admin' | 'source'; name?: string } };
        setConflict({
          changedBy: {
            kind: meta.changed_by?.kind === 'source' ? 'source' : 'admin',
            name: meta.changed_by?.name ?? '',
            at: new Date().toISOString(),
          },
          changes: patchChanges(state, initial),
        });
      } else {
        toast.show({ kind: 'error', title: toastCopy.saveFailed, description: copyForErrorCode(failure.code) });
      }
    }
  }

  async function reloadCurrent(): Promise<void> {
    if (matchId === null) return;
    const refreshed = await match.refetch();
    if (refreshed.data?.data) {
      const loaded = fromMatch(refreshed.data.data);
      setInitial(loaded);
      setState(loaded);
    }
    setConflict(null);
    setSaveError(null);
  }

  if (matchId !== null && match.isPending) {
    return <p className="text-label text-text-secondary">{copy.saving}</p>;
  }

  return (
    <div className="flex min-w-0 flex-1 flex-col gap-4">
      <div className="flex flex-wrap items-center gap-3">
        <div className="min-w-0">
          <p className="text-caption text-text-tertiary">{copy.breadcrumbRoot}</p>
          <h1 className="heading-1 text-text-primary">
            {matchId === null ? copy.newMatch : `${state.home.name} × ${state.away.name}`}
          </h1>
        </div>
        <span className="flex-1" />
        {saveError ? <p role="alert" className="text-label font-semibold text-error">{saveError}</p> : null}
        <Button variant="secondary" size="sm" onClick={() => navigate('/matches')}>
          {copy.discard}
        </Button>
        <Button size="sm" loading={patch.isPending || create.isPending} loadingLabel={copy.saving} onClick={() => void save()}>
          {copy.save}
        </Button>
      </div>

      <form className="flex min-w-0 flex-col gap-4" onSubmit={(event) => event.preventDefault()}>
        <EditorSections
          state={state}
          onChange={(next) => setState((current) => ({ ...current, ...next }))}
          competitions={competitors}
          lockedFields={match.data?.data?.locked_fields ?? []}
        />

        <ChannelsSection
          channels={state.channels}
          commentators={commentatorOptions}
          onChange={(channels) => setState((current) => ({ ...current, channels }))}
        />

        <BroadcastSlots
          broadcasts={state.broadcasts}
          commentators={commentatorOptions}
          onChange={(broadcasts) => setState((current) => ({ ...current, broadcasts }))}
        />

        <StatusSection
          state={state}
          onChange={(next) => setState((current) => ({ ...current, ...next }))}
          onReset={() => setState((current) => ({ ...current, statusMode: 'auto', scoreHome: '', scoreAway: '', homePen: '', awayPen: '' }))}
        />
      </form>

      <ConflictDialog
        open={conflict !== null}
        subject={`${state.home.name} × ${state.away.name}`}
        changedBy={conflict?.changedBy ?? { kind: 'admin', name: '', at: new Date().toISOString() }}
        changes={conflict?.changes ?? []}
        onReload={() => void reloadCurrent()}
        onClose={() => setConflict(null)}
      />

      <ConfirmDialog
        open={blocker.state === 'blocked'}
        title={copy.unsaved}
        body={copy.unsavedBody}
        confirmLabel={copy.saveAndLeave}
        onConfirm={() => {
          blocker.reset?.();
          void save().then(() => navigate('/matches'));
        }}
        onCancel={() => blocker.reset?.()}
      >
        <Button variant="ghost" size="sm" onClick={() => { blocker.proceed?.(); }}>
          {copy.leave}
        </Button>
      </ConfirmDialog>
    </div>
  );
}
