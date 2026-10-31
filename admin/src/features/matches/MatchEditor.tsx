import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useRef, useState, type ReactElement } from 'react';
import { useBlocker, useNavigate, useParams } from 'react-router-dom';

import { createMatch, patchMatch, useGetMatch, useListCommentators, useListCompetitions } from '../../api/generated/admin';
import type { AdminMatch, MatchCreate, MatchPatch, Period, Status } from '../../api/generated/admin.schemas';
import { createMatchBody, patchMatchBody } from '../../api/generated/admin.zod';
import { ApiError, etagOf, NETWORK_ERROR } from '../../api/http';
import { Button } from '../../components/Button/Button';
import { ConflictDialog, type ConflictChange } from '../../components/ConfirmDialog/ConflictDialog';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { EmptyState } from '../../components/EmptyState/EmptyState';
import { useToast } from '../../components/Toast/Toast';
import { EditorSections } from './editor/FieldsSection';
import { BroadcastSlots } from './editor/BroadcastSlots';
import { ChannelsSection } from './editor/ChannelsSection';
import { StatusSection } from './editor/StatusSection';
import { cairoDay, cairoWallTimeToUtc, formatCairoTime, utcToCairoWallTime } from '../../lib/cairoTime';
import { copyForErrorCode, editor as copy, toast as toastCopy } from '../../i18n/ar';

// A4 (admin board "Match editor"): one form over Orval's `patchMatchBody`, so what the API accepts is
// what the form checks. A save sends only the sections the editor changed, under the match's `If-Match`;
// a 409 opens ConflictDialog with the other side's version and can reload it into the form.

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
  minute: string;
  period: Period | '';
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
  /** Kept so a commentator-only edit never clears the slot's logo (A-R1-8). */
  logoAssetId: number | null;
  commentatorId: number | null;
}

/** What the editor loaded, and the version it must save under. */
export interface EditorBaseline {
  state: EditorState;
  lockedFields: readonly string[];
  etag: string | null;
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
    minute: match.status.minute ?? '',
    period: match.status.period ?? '',
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
    broadcasts: match.broadcasts
      .map((broadcast) => ({
        slot: (broadcast.slot === 2 ? 2 : 1) as 1 | 2,
        label: broadcast.label,
        logoAssetId: broadcast.logo_asset_id,
        commentatorId: broadcast.commentator_id,
      }))
      .sort((a, b) => a.slot - b.slot),
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
  minute: '',
  period: '',
  channels: [],
  broadcasts: [],
});

/** A new match starts on today's Cairo day, so the editor has a valid `match_date` to save (A-R1-4). */
export function draftState(now: string): EditorState {
  return { ...emptyState(), date: cairoDay(now) };
}

/** A manual status that shows a score needs both numbers, and half a score is never sent (A-R1-9). */
export function scoreIncomplete(state: EditorState): boolean {
  if (state.statusMode === 'auto' || !scoreAllowed(state.statusMode)) return false;
  const home = state.scoreHome.trim() !== '';
  const away = state.scoreAway.trim() !== '';
  if (scoreRequired(state.statusMode)) return !(home && away);
  // A score is optional here, but one box alone is not a score: neither 0–0 nor half a line.
  return home !== away;
}

/** The patch for the sections that changed, or an empty object when nothing did. */
export function buildPatch(current: EditorState, original: EditorState): MatchPatch {
  const patch: MatchPatch = {};
  const fields: NonNullable<MatchPatch['fields']> = {};

  if (current.date !== original.date || current.time !== original.time || current.timeTbd !== original.timeTbd) {
    fields.time_tbd = current.timeTbd;
    const wall = current.date && current.time ? `${current.date}T${current.time}` : '';
    fields.kickoff_at = current.timeTbd || wall === '' ? null : cairoWallTimeToUtc(wall);
    // A TBD match keeps its day editable: `match_date` travels with the cleared kickoff.
    if (current.date !== original.date) fields.match_date = current.date;
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

  const statusChanged =
    current.statusMode !== original.statusMode ||
    current.scoreHome !== original.scoreHome ||
    current.scoreAway !== original.scoreAway ||
    current.homePen !== original.homePen ||
    current.awayPen !== original.awayPen ||
    current.minute !== original.minute ||
    current.period !== original.period;
  if (statusChanged) {
    if (current.statusMode === 'auto') {
      patch.status = { clear: true };
    } else {
      const set: NonNullable<NonNullable<MatchPatch['status']>['set']> = { status: current.statusMode };
      // A score goes out only when both numbers are there: an optional-score status with both boxes
      // empty sends none, never a 0–0 made of blanks (A-R1-9).
      if (scoreAllowed(current.statusMode) && current.scoreHome !== '' && current.scoreAway !== '') {
        set.score = {
          home: Number(current.scoreHome),
          away: Number(current.scoreAway),
          home_pen: penaltiesAllowed(current.statusMode) && current.homePen !== '' ? Number(current.homePen) : null,
          away_pen: penaltiesAllowed(current.statusMode) && current.awayPen !== '' ? Number(current.awayPen) : null,
        };
      }
      if (current.minute !== '') set.minute = current.minute;
      if (current.period !== '') set.period = current.period;
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
      (before && before.logoAssetId !== broadcast.logoAssetId) ||
      (broadcast.label === '' && before !== undefined)
    );
  });
  if (broadcastsChanged) {
    patch.broadcasts = current.broadcasts
      .filter((broadcast) => broadcast.label !== '')
      .map((broadcast) => ({
        slot: broadcast.slot,
        label: broadcast.label,
        logo_asset_id: broadcast.logoAssetId,
        commentator_id: broadcast.commentatorId,
      }));
  }

  return patch;
}

/** A new match's body, validated by Orval's `createMatchBody`: no cast, no shape guessing (A-R1-4). */
export function buildCreate(current: EditorState): MatchCreate | null {
  const wall = current.date && current.time ? `${current.date}T${current.time}` : '';
  const candidate: MatchCreate = {
    match_date: current.date,
    time_tbd: current.timeTbd,
    kickoff_at: current.timeTbd || wall === '' ? null : cairoWallTimeToUtc(wall),
    home: current.home.teamId === null ? { name: current.home.name } : { team_id: current.home.teamId },
    away: current.away.teamId === null ? { name: current.away.name } : { team_id: current.away.teamId },
  };
  if (current.competitionId !== '') candidate.competition_id = Number(current.competitionId);
  if (current.stage !== '') candidate.competition_stage = current.stage;
  if (current.stadium !== '') candidate.stadium = current.stadium;
  const parsed = createMatchBody.safeParse(candidate);
  return parsed.success ? (parsed.data as MatchCreate) : null;
}

/** The difference between the version the editor loaded and the one the server now holds. */
export function diffStates(before: EditorState, after: EditorState): ConflictChange[] {
  const changes: ConflictChange[] = [];
  const clock = (state: EditorState): string | null =>
    state.timeTbd
      ? copy.timeTbd
      : state.date && state.time
        ? formatCairoTime(cairoWallTimeToUtc(`${state.date}T${state.time}`))
        : null;
  if (before.date !== after.date || before.time !== after.time || before.timeTbd !== after.timeTbd) {
    changes.push({ field: 'kickoff_at', label: copy.time, before: clock(before), after: clock(after) });
  }
  if (before.competitionId !== after.competitionId) {
    changes.push({ field: 'competition_id', label: copy.competition, before: before.competitionId || null, after: after.competitionId || null });
  }
  if (before.stage !== after.stage) {
    changes.push({ field: 'competition_stage', label: copy.stage, before: before.stage || null, after: after.stage || null });
  }
  if (before.stadium !== after.stadium) {
    changes.push({ field: 'stadium', label: copy.stadium, before: before.stadium || null, after: after.stadium || null });
  }
  if (before.statusMode !== after.statusMode) {
    changes.push({ field: 'status', label: copy.status, before: before.statusMode, after: after.statusMode });
  }
  if (before.channels.length !== after.channels.length) {
    changes.push({
      field: 'channels',
      label: copy.channels,
      before: String(before.channels.length),
      after: String(after.channels.length),
    });
  }
  return changes;
}

interface ConflictState {
  changedBy: { kind: 'admin' | 'source'; name: string; at: string };
  changes: ConflictChange[];
  /** The version the server holds, adopted by «إعادة التحميل». */
  theirs: EditorBaseline;
}

function EditorSkeleton(): ReactElement {
  return (
    <div data-testid="editor-skeleton" className="flex flex-col gap-3 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider">
      <p className="text-label text-text-secondary">{copy.loading}</p>
      {[0, 1, 2].map((row) => (
        <div key={row} className="flex h-12 items-center gap-3">
          <span className="h-3 w-12 rounded-xs bg-surface-2" />
          <span className="h-8 flex-1 rounded-md bg-surface-2" />
        </div>
      ))}
    </div>
  );
}

export function MatchEditor(): ReactElement {
  const { id } = useParams<{ id: string }>();
  const numericId = id === undefined ? null : Number(id);
  const validId = numericId !== null && Number.isInteger(numericId) && numericId > 0;
  const matchId = validId ? numericId : null;
  const navigate = useNavigate();
  const toast = useToast();
  const [baseline, setBaseline] = useState<EditorBaseline | null>(null);
  const [state, setState] = useState<EditorState>(emptyState);
  const [conflict, setConflict] = useState<ConflictState | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);

  const match = useGetMatch(matchId ?? 0, { query: { enabled: matchId !== null } });
  const queryClient = useQueryClient();
  const [saving, setSaving] = useState(false);
  const competitions = useListCompetitions();
  const commentators = useListCommentators({ limit: 100 });

  // The version comes from the response that filled the form, never a second `GET` (A-R1-3). Only the
  // first answer for this match seeds the form: a later refetch (after a save, or a list invalidation)
  // must not reset the version the editor is working under.
  const seeded = useRef<number | null>(null);
  useEffect(() => {
    if (!match.data?.data || seeded.current === matchId) return;
    seeded.current = matchId;
    leavingAfterSave.current = false;
    const loaded = fromMatch(match.data.data);
    setBaseline({ state: loaded, lockedFields: match.data.data.locked_fields, etag: etagOf(match.data) });
    setState(loaded);
  }, [match.data, matchId]);

  // «إضافة مباراة»: the create route is a real draft, with today's Cairo day already set.
  useEffect(() => {
    if (id !== undefined) return;
    const draft: EditorBaseline = { state: draftState(new Date().toISOString()), lockedFields: [], etag: null };
    setBaseline(draft);
    setState(draft.state);
  }, [id]);

  const dirty = useMemo(() => {
    if (baseline === null) return false;
    if (matchId === null) return JSON.stringify(state) !== JSON.stringify(baseline.state);
    return JSON.stringify(buildPatch(state, baseline.state)) !== '{}';
  }, [baseline, matchId, state]);

  // A create navigates to the match it just made: that move is the save's own, so it must not be
  // caught by the unsaved-changes guard (the guard's closure still sees the draft as dirty).
  const leavingAfterSave = useRef(false);
  const blocker = useBlocker(
    ({ currentLocation, nextLocation }) =>
      !leavingAfterSave.current && dirty && currentLocation.pathname !== nextLocation.pathname,
  );
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

  function adopt(server: EditorBaseline): void {
    setBaseline(server);
    setState(server.state);
    setConflict(null);
    setSaveError(null);
  }

  async function openConflict(failure: ApiError): Promise<void> {
    const meta = failure.meta as {
      changed_by?: { kind?: 'admin' | 'source'; name?: string };
      changed_at?: string;
    };
    const refreshed = await match.refetch();
    const current = refreshed.data?.data;
    if (!current || baseline === null) {
      setSaveError(copyForErrorCode(failure.code));
      return;
    }
    const theirs = fromMatch(current);
    setConflict({
      changedBy: {
        kind: meta.changed_by?.kind === 'source' ? 'source' : 'admin',
        name: meta.changed_by?.name ?? '',
        at: meta.changed_at ?? new Date().toISOString(),
      },
      changes: diffStates(baseline.state, theirs),
      theirs: { state: theirs, lockedFields: current.locked_fields, etag: etagOf(refreshed.data) },
    });
  }

  /**
   * The baseline the save produced, or null when it failed. `If-Match` is the version the editor
   * loaded, sent explicitly on the call, so a second save never reuses the first one's stale copy
   * (A-R1-2, A-R1-3). The caller adopts the result only after deciding whether to leave the screen.
   */
  async function save(): Promise<EditorBaseline | null> {
    if (baseline === null) return null;
    setSaveError(null);
    setSaving(true);

    try {
      if (matchId === null) {
        const body = buildCreate(state);
        if (body === null) {
          setSaveError(copyForErrorCode('validation_error'));
          return null;
        }
        const created = await createMatch(body);
        toast.show({ kind: 'success', title: toastCopy.saved });
        if (created.data) {
          leavingAfterSave.current = true;
          navigate(`/matches/${created.data.id}`, { replace: true });
          return { state: fromMatch(created.data), lockedFields: created.data.locked_fields, etag: etagOf(created) };
        }
        return { state, lockedFields: baseline.lockedFields, etag: etagOf(created) };
      }

      const built = buildPatch(state, baseline.state);
      if (Object.keys(built).length === 0) return baseline;
      if (scoreIncomplete(state)) {
        setSaveError(copy.scoreRequired);
        return null;
      }
      const parsed = patchMatchBody.safeParse(built);
      if (!parsed.success) {
        setSaveError(copyForErrorCode('validation_error'));
        return null;
      }

      const saved = await patchMatch(matchId, parsed.data as MatchPatch, {
        headers: baseline.etag ? { 'If-Match': baseline.etag } : {},
      });
      void queryClient.invalidateQueries();
      toast.show({ kind: 'success', title: toastCopy.saved });
      return saved.data
        ? { state: fromMatch(saved.data), lockedFields: saved.data.locked_fields, etag: etagOf(saved) }
        : { state, lockedFields: baseline.lockedFields, etag: etagOf(saved) };
    } catch (error) {
      const failure = error instanceof ApiError ? error : new ApiError(NETWORK_ERROR, null);
      setSaveError(copyForErrorCode(failure.code));
      if (failure.code === 'edit_conflict') {
        await openConflict(failure);
      } else {
        toast.show({ kind: 'error', title: toastCopy.saveFailed, description: copyForErrorCode(failure.code) });
      }
      return null;
    } finally {
      setSaving(false);
    }
  }

  async function saveHere(): Promise<void> {
    const saved = await save();
    if (saved) adopt(saved);
  }

  /** «احفظ وغادر»: leave only once the save stuck, and go where the editor was going (A-R1-16). */
  async function saveAndLeave(): Promise<void> {
    const saved = await save();
    if (saved) {
      // `proceed` first: adopting the server state clears `dirty`, and the router then stops blocking.
      blocker.proceed?.();
      adopt(saved);
    } else {
      blocker.reset?.();
    }
  }

  if (id !== undefined && !validId) {
    return (
      <EmptyState
        kind="error"
        title={copyForErrorCode('match_not_found')}
        body={copy.loadFailedBody}
        action={{ label: copy.backToMatches, onClick: () => navigate('/matches') }}
      />
    );
  }

  if (matchId !== null && match.isPending) return <EditorSkeleton />;

  if (matchId !== null && match.isError) {
    return (
      <EmptyState
        kind="error"
        title={copyForErrorCode(match.error?.code ?? '')}
        body={copy.loadFailedBody}
        action={{ label: toastCopy.retry, onClick: () => void match.refetch() }}
      />
    );
  }

  return (
    <div className="flex min-w-0 flex-1 flex-col gap-4">
      <div className="flex flex-wrap items-center gap-3">
        <div className="min-w-0">
          <p className="text-caption text-text-tertiary">{copy.breadcrumbRoot}</p>
          <h1 className="heading-1 text-text-primary">
            {matchId === null ? (
              copy.newMatch
            ) : (
              <>
                <bdi>{state.home.name}</bdi> × <bdi>{state.away.name}</bdi>
              </>
            )}
          </h1>
        </div>
        <span className="flex-1" />
        {saveError ? <p role="alert" className="text-label font-semibold text-error">{saveError}</p> : null}
        <Button variant="secondary" size="sm" onClick={() => navigate('/matches')}>
          {copy.discard}
        </Button>
        <Button size="sm" loading={saving} loadingLabel={copy.saving} onClick={() => void saveHere()}>
          {copy.save}
        </Button>
      </div>

      <form className="flex min-w-0 flex-col gap-4" onSubmit={(event) => event.preventDefault()}>
        <EditorSections
          state={state}
          onChange={(next) => setState((current) => ({ ...current, ...next }))}
          competitions={competitors}
          lockedFields={baseline?.lockedFields ?? []}
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
          onReset={() =>
            setState((current) => ({
              ...current,
              statusMode: 'auto',
              scoreHome: '',
              scoreAway: '',
              homePen: '',
              awayPen: '',
              minute: '',
              period: '',
            }))
          }
        />
      </form>

      <ConflictDialog
        open={conflict !== null}
        subject={
          <>
            <bdi>{state.home.name}</bdi> × <bdi>{state.away.name}</bdi>
          </>
        }
        changedBy={conflict?.changedBy ?? { kind: 'admin', name: '', at: new Date().toISOString() }}
        changes={conflict?.changes ?? []}
        onReload={() => conflict && adopt(conflict.theirs)}
        onDiscard={() => {
          // «تجاهل تعديلاتي» really drops them: the form goes back to the version it loaded (A-R1-5).
          if (baseline !== null) setState(baseline.state);
          setConflict(null);
        }}
      />

      <ConfirmDialog
        open={blocker.state === 'blocked'}
        title={copy.unsaved}
        body={copy.unsavedBody}
        confirmLabel={copy.saveAndLeave}
        cancelLabel={copy.stay}
        onConfirm={() => void saveAndLeave()}
        onCancel={() => blocker.reset?.()}
      >
        <Button variant="ghost" size="sm" onClick={() => { blocker.proceed?.(); }}>
          {copy.leave}
        </Button>
      </ConfirmDialog>
    </div>
  );
}
