import { useEffect, useState, type ReactElement } from 'react';

import { createAnnouncement, putTestDevice, sendTest } from '../../api/generated/admin';
import { ApiError, etagOf, INVALID_RESPONSE } from '../../api/http';
import { Button } from '../../components/Button/Button';
import { ConfirmDialog } from '../../components/ConfirmDialog/ConfirmDialog';
import { Counter, Segmented, Select } from '../../components/FormControls/FormControls';
import { Field } from '../../components/Field/Field';
import { Icon } from '../../components/Icon/Icon';
import { useToast } from '../../components/Toast/Toast';
import { cairoWallTimeToUtc, formatCairoTime } from '../../lib/cairoTime';
import { useRefreshAdmin } from '../../lib/useRefreshAdmin';
import { copyForErrorCode, notifications as copy } from '../../i18n/ar';
import { useCompetitions } from '../competitions/queries';
import { ChannelPicker } from '../matches/ChannelPicker';
import { TeamPicker } from '../matches/TeamPicker';
import { MatchPicker, type PickedMatch } from './MatchPicker';
import { useReach, useTestDevice } from './queries';

// A15's composer (contract admin-screens "Composer", board "Notifications"): an inline announcement —
// title and body with their counters, an optional deep link whose route the server builds, one of the
// five audiences with its reach, now or a Cairo time, both previews, the confirmation before «كل
// الأجهزة», and the test send that reports what its outbox row did. Admin only.

type AudienceKind = 'all' | 'team' | 'competition' | 'match' | 'channel';

interface Picked<T> {
  id: number;
  label: string;
  extra?: T;
}

const AUDIENCE_KINDS: readonly { value: AudienceKind; label: string }[] = [
  { value: 'all', label: copy.composer.kinds.all },
  { value: 'team', label: copy.composer.kinds.team },
  { value: 'competition', label: copy.composer.kinds.competition },
  { value: 'match', label: copy.composer.kinds.match },
  { value: 'channel', label: copy.composer.kinds.channel },
];

const TITLE_MAX = 65;
const BODY_MAX = 180;
const REACH_DEBOUNCE_MS = 300;

const number = (value: number): string => new Intl.NumberFormat('en-US').format(value);

export function Composer(): ReactElement | null {
  const toast = useToast();
  const refresh = useRefreshAdmin();
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [target, setTarget] = useState<Picked<{ route: string; type: 'match' | 'channel' }> | null>(null);
  const [audienceKind, setAudienceKind] = useState<AudienceKind>('all');
  const [audience, setAudience] = useState<Picked<unknown> | null>(null);
  const [when, setWhen] = useState<'now' | 'scheduled'>('now');
  const [wall, setWall] = useState('');
  const [whenError, setWhenError] = useState<string | null>(null);
  const [confirming, setConfirming] = useState(false);
  const [posting, setPosting] = useState(false);
  const [deviceId, setDeviceId] = useState('');
  const [reachFor, setReachFor] = useState<{ kind: AudienceKind; id: number | null }>({ kind: 'all', id: null });

  const device = useTestDevice();
  const saved = device.data?.data ?? null;
  const reach = useReach(reachFor.kind, reachFor.id);

  // «الآن» for all, or the picked id for the four narrower audiences. A kind change clears the pick.
  const audienceId = audienceKind === 'all' ? null : (audience?.id ?? null);
  const audienceReady = audienceKind === 'all' || audienceId !== null;

  useEffect(() => {
    const timer = setTimeout(() => setReachFor({ kind: audienceKind, id: audienceId }), REACH_DEBOUNCE_MS);
    return () => clearTimeout(timer);
  }, [audienceKind, audienceId]);

  const devices = reach.data?.data?.devices;
  const reachText = devices === undefined ? null : copy.composer.reach(number(devices));
  const reachAge =
    reach.dataUpdatedAt === 0 ? null : copy.composer.reachAge(Math.max(0, Math.round((Date.now() - reach.dataUpdatedAt) / 1000)));

  const ready = title.trim() !== '' && body.trim() !== '' && audienceReady && !posting;

  function pickTarget(match: PickedMatch): void {
    setTarget({ id: match.id, label: match.label, extra: { route: match.route, type: 'match' } });
  }

  function onKind(kind: AudienceKind): void {
    setAudienceKind(kind);
    setAudience(null);
  }

  async function submit(): Promise<void> {
    let sendAt: string | null = null;
    if (when === 'scheduled') {
      if (wall === '') {
        setWhenError(copy.composer.whenRequired);
        return;
      }
      sendAt = cairoWallTimeToUtc(wall);
      if (new Date(sendAt).getTime() <= Date.now()) {
        setWhenError(copy.composer.whenPast);
        return;
      }
    }
    setWhenError(null);
    setConfirming(false);
    setPosting(true);
    try {
      const envelope = await createAnnouncement({
        title,
        body,
        target: { type: target?.extra?.type ?? 'none', id: target?.id ?? null },
        audience: { kind: audienceKind, id: audienceId },
        send_at: sendAt,
      });
      if (!envelope.success) throw new ApiError(INVALID_RESPONSE, null);
      toast.show({ kind: 'success', title: sendAt === null ? copy.composer.sent : copy.composer.scheduledDone });
      setTitle('');
      setBody('');
      setTarget(null);
      refresh();
    } catch (error) {
      const code = error instanceof ApiError ? error.code : INVALID_RESPONSE;
      toast.show({ kind: 'error', title: copyForErrorCode(code) });
    } finally {
      setPosting(false);
    }
  }

  function send(): void {
    if (when === 'scheduled') {
      if (wall === '') {
        setWhenError(copy.composer.whenRequired);
        return;
      }
      if (new Date(cairoWallTimeToUtc(wall)).getTime() <= Date.now()) {
        setWhenError(copy.composer.whenPast);
        return;
      }
    }
    setWhenError(null);
    // «كل الأجهزة» is the one send that can't be taken back at a glance: confirm it with its reach.
    if (audienceKind === 'all') {
      setConfirming(true);
      return;
    }
    void submit();
  }

  async function onTestSend(): Promise<void> {
    try {
      const envelope = await sendTest({
        title,
        body,
        target: { type: target?.extra?.type ?? 'none', id: target?.id ?? null },
      });
      if (!envelope.success) throw new ApiError(INVALID_RESPONSE, null);
      toast.show({ kind: 'success', title: copy.composer.testSent(deviceName(saved)) });
      refresh();
    } catch (error) {
      const code = error instanceof ApiError ? error.code : INVALID_RESPONSE;
      toast.show({ kind: 'error', title: copyForErrorCode(code) });
    }
  }

  async function onSaveDevice(): Promise<void> {
    const id = Number(deviceId);
    if (!Number.isInteger(id) || id <= 0) {
      toast.show({ kind: 'error', title: copyForErrorCode('validation_error') });
      return;
    }
    try {
      await putTestDevice({ device_id: id }, { headers: ifMatchHeader(device.data) });
      setDeviceId('');
      toast.show({ kind: 'success', title: copy.composer.deviceSaved });
      await device.refetch();
    } catch (error) {
      const code = error instanceof ApiError ? error.code : INVALID_RESPONSE;
      toast.show({ kind: 'error', title: copyForErrorCode(code) });
      // A conflict means their version moved: re-read it, and the next save carries that one.
      if (code === 'edit_conflict') await device.refetch();
    }
  }

  return (
    <section
      aria-label={copy.composer.title}
      className="flex min-w-0 flex-col gap-4 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider"
    >
      <h2 className="heading-2 flex items-center gap-2 text-text-primary">
        <Icon name="bell" size="lg" className="text-accent-text" />
        {copy.composer.title}
      </h2>

      <Field
        label={copy.composer.titleField}
        value={title}
        maxLength={TITLE_MAX}
        onChange={(event) => setTitle(event.target.value)}
        trailing={<Counter length={title.length} max={TITLE_MAX} />}
      />

      <div className="flex min-w-0 flex-col gap-2">
        <div className="flex items-center gap-2">
          <label htmlFor="composer-body" className="text-caption font-semibold text-text-secondary">
            {copy.composer.bodyField}
          </label>
          <span className="ms-auto">
            <Counter length={body.length} max={BODY_MAX} />
          </span>
        </div>
        <textarea
          id="composer-body"
          aria-label={copy.composer.bodyField}
          rows={2}
          maxLength={BODY_MAX}
          value={body}
          onChange={(event) => setBody(event.target.value)}
          className="text-body min-w-0 rounded-md bg-bg px-3 py-2 text-text-primary ring-1 ring-inset ring-divider-strong focus-visible:ring-2 focus-visible:ring-focus-ring"
        />
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <div className="flex min-w-0 flex-col gap-2">
          <span className="text-caption font-semibold text-text-secondary">{copy.composer.target}</span>
          {target === null ? (
            <MatchPicker trigger={copy.composer.pickMatch} onPick={pickTarget} />
          ) : (
            <div className="flex flex-wrap items-center gap-2 rounded-md bg-bg px-3 py-2">
              <Icon name="ball" size="sm" className="text-text-tertiary" />
              <bdi className="text-label min-w-0 flex-1 truncate text-text-primary">{target.label}</bdi>
              <bdi dir="ltr" className="text-micro font-mono text-text-tertiary">
                {target.extra?.route}
              </bdi>
              <Button size="xs" variant="ghost" onClick={() => setTarget(null)}>
                {copy.composer.clearTarget}
              </Button>
            </div>
          )}
        </div>

        <div className="flex min-w-0 flex-col gap-2">
          <span className="text-caption font-semibold text-text-secondary">{copy.composer.when}</span>
          <div className="flex flex-wrap items-center gap-2">
            <Segmented
              label={copy.composer.when}
              value={when}
              options={[
                { value: 'now', label: copy.composer.now },
                { value: 'scheduled', label: copy.composer.scheduled },
              ]}
              onChange={(value) => {
                setWhen(value);
                setWhenError(null);
              }}
            />
            {when === 'scheduled' ? (
              <Field
                label={copy.composer.whenLabel}
                type="datetime-local"
                ltr
                value={wall}
                error={whenError ?? undefined}
                onChange={(event) => {
                  setWall(event.target.value);
                  setWhenError(null);
                }}
              />
            ) : null}
          </div>
        </div>
      </div>

      <fieldset className="flex min-w-0 flex-col gap-2">
        <legend className="text-caption font-semibold text-text-secondary">{copy.composer.audience}</legend>
        <div className="flex flex-wrap gap-2">
          {AUDIENCE_KINDS.map((kind) => (
            <label
              key={kind.value}
              className={`text-label flex items-center gap-2 rounded-md px-3 py-2 ring-1 ring-inset ${
                audienceKind === kind.value ? 'bg-accent-container text-accent-text ring-accent' : 'bg-bg text-text-secondary ring-divider'
              }`}
            >
              <input
                type="radio"
                name="audience"
                aria-label={kind.label}
                checked={audienceKind === kind.value}
                onChange={() => onKind(kind.value)}
                className="size-4 accent-accent"
              />
              {kind.label}
            </label>
          ))}
        </div>

        {audienceKind === 'team' ? (
          <TeamPicker
            label={copy.composer.team}
            teamId={audience?.id ?? null}
            name={audience?.label ?? ''}
            onChange={(value) =>
              setAudience(value.teamId === null ? null : { id: value.teamId, label: value.name })
            }
          />
        ) : audienceKind === 'competition' ? (
          <CompetitionChoice value={audienceId} onPick={setAudience} />
        ) : audienceKind === 'match' ? (
          <MatchPicker
            onPick={(match) => setAudience({ id: match.id, label: match.label })}
          />
        ) : audienceKind === 'channel' ? (
          <ChannelChoice value={audienceId} onPick={setAudience} />
        ) : null}

        <p className="text-caption text-text-tertiary">
          {reachText ?? copy.composer.reachUnavailable}
          {reachText !== null && reachAge !== null ? ` · ${reachAge}` : null}
        </p>
      </fieldset>

      <div className="flex flex-wrap items-center gap-2">
        <Button variant="outline" size="sm" onClick={() => void onTestSend()}>
          <Icon name="signal" size="sm" />
          {copy.composer.testSend}
        </Button>
        {saved === null ? (
          <span className="flex flex-wrap items-end gap-2">
            <Field
              label={copy.composer.deviceId}
              value={deviceId}
              ltr
              mono
              onChange={(event) => setDeviceId(event.target.value)}
            />
            <Button size="sm" variant="secondary" onClick={() => void onSaveDevice()}>
              {copy.composer.saveDevice}
            </Button>
          </span>
        ) : (
          <span className="text-caption text-text-secondary">
            {copy.composer.platforms[saved.platform] ?? saved.platform} ·{' '}
            <bdi dir="ltr" className="font-mono">
              {saved.app_version ?? '—'}
            </bdi>
          </span>
        )}
        <span className="flex-1" />
        <Button size="sm" variant="primary" disabled={!ready} onClick={send}>
          <Icon name="clock" size="sm" />
          {when === 'scheduled' ? copy.composer.schedule : copy.composer.send}
        </Button>
      </div>

      <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
        <Preview platform={copy.composer.preview.android} title={title} body={body} />
        <Preview platform={copy.composer.preview.iphone} title={title} body={body} />
      </div>

      <ConfirmDialog
        open={confirming}
        title={copy.composer.confirmTitle}
        body={copy.composer.confirmBody(reachText ?? '—')}
        confirmLabel={copy.composer.confirm}
        onConfirm={() => void submit()}
        onCancel={() => setConfirming(false)}
      />
    </section>
  );
}

/** The account's device as one line: «Android · 0.6.0+60». */
function deviceName(device: { platform: string; app_version: string | null } | null): string {
  if (!device) return '—';
  return `${device.platform} · ${device.app_version ?? '—'}`;
}

function ifMatchHeader(envelope: unknown): Record<string, string> {
  const etag = etagOf(envelope);
  return etag ? { 'If-Match': etag } : {};
}

function Preview({ platform, title, body }: { platform: string; title: string; body: string }): ReactElement {
  return (
    <div className="flex min-w-0 flex-col gap-2">
      <span className="text-caption text-text-tertiary">{platform}</span>
      <div className="flex min-w-0 flex-col gap-1 rounded-xl bg-surface-2 p-3 ring-1 ring-inset ring-divider">
        <span className="text-micro flex items-center gap-2 text-text-tertiary">
          {copy.composer.preview.appName} · {formatCairoTime(new Date().toISOString())}
        </span>
        <bdi className="text-label font-semibold text-text-primary">{title}</bdi>
        <span className="text-caption text-text-secondary">{body}</span>
      </div>
    </div>
  );
}

/** A15's competition audience: one pick from `useCompetitions()`. */
function CompetitionChoice({
  value,
  onPick,
}: {
  value: number | null;
  onPick: (picked: Picked<unknown> | null) => void;
}): ReactElement {
  const competitions = useCompetitions();
  const rows = competitions.rows;
  return (
    <Select
      label={copy.composer.competition}
      value={value === null ? '' : String(value)}
      options={[
        { value: '', label: copy.filters.all },
        ...rows.map((competition) => ({ value: String(competition.id), label: competition.name })),
      ]}
      onChange={(next) => {
        const picked = rows.find((competition) => String(competition.id) === next);
        onPick(picked ? { id: picked.id, label: picked.name } : null);
      }}
    />
  );
}

/** A15's channel audience: `ChannelPicker`'s single-select mode. */
function ChannelChoice({
  value,
  onPick,
}: {
  value: number | null;
  onPick: (picked: Picked<unknown> | null) => void;
}): ReactElement {
  return (
    <ChannelPicker
      selectedId={value}
      onSelect={(channel) =>
        onPick({ id: channel.id, label: displayName(channel.name, channel.display_name) })
      }
    />
  );
}

function displayName(name: string, display: string | null): string {
  return display ?? name;
}
