import { useId, useState, type ReactElement } from 'react';

import { useAddHiddenChannelName, useRemoveHiddenChannelName } from '../../../api/generated/admin';
import type { ChannelItem } from '../../../api/generated/admin.schemas';
import { ApiError } from '../../../api/http';
import { Button } from '../../../components/Button/Button';
import { ConfirmDialog } from '../../../components/ConfirmDialog/ConfirmDialog';
import { Icon } from '../../../components/Icon/Icon';
import { useToast } from '../../../components/Toast/Toast';
import { copyForErrorCode, editor as copy, toast as toastCopy } from '../../../i18n/ar';
import { ChannelPicker } from '../ChannelPicker';
import type { EditorChannel } from '../MatchEditor';

// A4's "القنوات الناقلة": one link per channel, with its source and commentator. Hiding applies to
// this match only, unless the editor hides the name everywhere — that one is destructive and typed.
// A failed «دائماً» action keeps the dialog open and says so, instead of rejecting unhandled (A-R1-14).
interface ChannelsSectionProps {
  channels: readonly EditorChannel[];
  commentators: readonly { id: number; name: string }[];
  onChange: (next: EditorChannel[]) => void;
}

export function ChannelsSection({ channels, commentators, onChange }: ChannelsSectionProps): ReactElement {
  const addHidden = useAddHiddenChannelName();
  const removeHidden = useRemoveHiddenChannelName();
  const toast = useToast();
  const prefix = useId();
  const [hiding, setHiding] = useState<EditorChannel | null>(null);
  const [failure, setFailure] = useState<string | null>(null);

  function update(index: number, patch: Partial<EditorChannel>): void {
    onChange(channels.map((channel, position) => (position === index ? { ...channel, ...patch } : channel)));
  }

  function report(error: unknown): void {
    const code = error instanceof ApiError ? error.code : 'network_error';
    setFailure(copyForErrorCode(code));
    toast.show({ kind: 'error', title: toastCopy.saveFailed, description: copyForErrorCode(code) });
  }

  function add(channel: ChannelItem): void {
    if (channels.some((link) => link.channelId === channel.id)) return;
    onChange([
      ...channels,
      {
        channelId: channel.id,
        name: channel.name,
        displayName: channel.display_name,
        source: 'manual',
        satellite: null,
        frequency: channel.frequency ? `${channel.frequency.mhz} ${channel.frequency.pol}` : null,
        isHidden: false,
        hiddenByName: channel.hidden_by_name,
        commentatorId: null,
        commentator2Id: null,
      },
    ]);
  }

  async function hideEverywhere(): Promise<void> {
    if (!hiding) return;
    setFailure(null);
    try {
      await addHidden.mutateAsync({ data: { name: hiding.displayName ?? hiding.name } });
      update(
        channels.findIndex((channel) => channel.channelId === hiding.channelId),
        { hiddenByName: true },
      );
      setHiding(null);
    } catch (error) {
      report(error);
    }
  }

  async function showAgain(channel: EditorChannel, index: number): Promise<void> {
    setFailure(null);
    try {
      await removeHidden.mutateAsync({ name: encodeURIComponent(channel.displayName ?? channel.name) });
      update(index, { hiddenByName: false });
    } catch (error) {
      report(error);
    }
  }

  return (
    <section aria-label={copy.channels} className="flex flex-col gap-3 rounded-xl bg-surface-1 p-4 ring-1 ring-inset ring-divider">
      <div className="flex flex-wrap items-center gap-2">
        <h2 className="text-label font-semibold text-text-primary">{copy.channels}</h2>
        <span className="text-micro rounded-xs bg-surface-2 px-2 text-text-secondary">{copy.channelCount(channels.length)}</span>
        {failure ? (
          <p role="alert" className="text-caption font-semibold text-error">
            {failure}
          </p>
        ) : null}
      </div>

      {channels.length === 0 ? (
        <p className="text-caption text-text-tertiary">{copy.noChannels}</p>
      ) : (
        <ul className="flex flex-col divide-y divide-divider">
          {channels.map((channel, index) => {
            // The visible name is its own direction island; the controls point at it, so a Latin
            // channel name never runs into the Arabic label (A-R1-18).
            const nameId = `${prefix}-name-${channel.channelId}`;
            const hideId = `${prefix}-hide-${channel.channelId}`;
            const firstId = `${prefix}-first-${channel.channelId}`;
            const secondId = `${prefix}-second-${channel.channelId}`;
            return (
              <li key={channel.channelId} data-testid={`channel-link-${channel.channelId}`} className="flex flex-wrap items-center gap-3 py-3">
                <span className="flex min-w-0 flex-1 flex-col">
                  <bdi id={nameId} className="text-label truncate text-text-primary">
                    {channel.name}
                  </bdi>
                  <span className="text-micro flex flex-wrap items-center gap-2 text-text-tertiary">
                    <span dir="ltr" className="rounded-xs bg-surface-2 px-1 py-1 font-mono">
                      {channel.source}
                    </span>
                    {channel.satellite ? <bdi>{channel.satellite}</bdi> : null}
                    {channel.frequency ? (
                      <span dir="ltr" className="font-mono">
                        {channel.frequency}
                      </span>
                    ) : null}
                    {channel.hiddenByName ? <span className="text-postponed">{copy.hiddenAlways}</span> : null}
                  </span>
                  <span id={hideId} hidden>{copy.hideFromMatch}</span>
                  <span id={firstId} hidden>{copy.commentator(1)}</span>
                  <span id={secondId} hidden>{copy.commentator(2)}</span>
                </span>

                <label className="text-caption flex items-center gap-2 text-text-secondary">
                  <input
                    type="checkbox"
                    checked={channel.isHidden}
                    onChange={(event) => update(index, { isHidden: event.target.checked })}
                    className="size-4 accent-accent"
                    aria-labelledby={`${hideId} ${nameId}`}
                  />
                  {copy.hideFromMatch}
                </label>

                {channel.hiddenByName ? (
                  <Button variant="ghost" size="xs" onClick={() => void showAgain(channel, index)}>
                    {copy.show}
                  </Button>
                ) : (
                  <Button variant="ghost" size="xs" onClick={() => setHiding(channel)}>
                    <Icon name="eyeOff" size="sm" /> {copy.hideAlways}
                  </Button>
                )}

                <label className="flex flex-col gap-1">
                  <span className="text-micro text-text-tertiary">{copy.commentator(1)}</span>
                  <select
                    aria-labelledby={`${firstId} ${nameId}`}
                    value={channel.commentatorId ?? ''}
                    onChange={(event) => {
                      const commentatorId = event.target.value === '' ? null : Number(event.target.value);
                      update(index, { commentatorId, commentator2Id: commentatorId === null ? null : channel.commentator2Id });
                    }}
                    className="text-caption h-8 rounded-md bg-bg px-2 text-text-primary ring-1 ring-inset ring-divider-strong"
                  >
                    <option value="">{copy.none}</option>
                    {commentators.map((person) => (
                      <option key={person.id} value={person.id}>
                        {person.name}
                      </option>
                    ))}
                  </select>
                </label>

                <label className="flex flex-col gap-1">
                  <span className="text-micro text-text-tertiary">{copy.commentator(2)}</span>
                  <select
                    aria-labelledby={`${secondId} ${nameId}`}
                    disabled={channel.commentatorId === null}
                    value={channel.commentator2Id ?? ''}
                    onChange={(event) => update(index, { commentator2Id: event.target.value === '' ? null : Number(event.target.value) })}
                    className="text-caption h-8 rounded-md bg-bg px-2 text-text-primary ring-1 ring-inset ring-divider-strong disabled:opacity-50"
                  >
                    <option value="">{copy.none}</option>
                    {commentators.map((person) => (
                      <option key={person.id} value={person.id}>
                        {person.name}
                      </option>
                    ))}
                  </select>
                </label>

                <Button
                  variant="ghost"
                  size="xs"
                  onClick={() => onChange(channels.filter((_, position) => position !== index))}
                >
                  {copy.remove}
                </Button>
              </li>
            );
          })}
        </ul>
      )}

      <h3 className="text-caption font-semibold text-text-secondary">{copy.addChannel}</h3>
      <ChannelPicker onAdd={add} />

      <ConfirmDialog
        open={hiding !== null}
        title={<>{copy.hideTitleBefore}<bdi dir="ltr">«{hiding?.name ?? ''}»</bdi>{copy.hideTitleAfter}</>}
        body={copy.hideBody}
        phrase={copy.hidePhrase}
        confirmLabel={copy.hideAlways}
        destructive
        loading={addHidden.isPending}
        onConfirm={() => void hideEverywhere()}
        onCancel={() => {
          setFailure(null);
          setHiding(null);
        }}
      />
    </section>
  );
}
