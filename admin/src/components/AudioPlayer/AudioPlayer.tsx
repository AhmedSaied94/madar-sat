import { clsx } from 'clsx';
import { useCallback, useEffect, useRef, useState, type ReactElement } from 'react';

import { audio as copy, common } from '../../i18n/ar';
import { focusRing } from '../focus';
import { Icon } from '../Icon/Icon';

// A commentator's short voice sample (A10, CommentatorRow README): idle, loading, playing, paused
// and error over a native <audio>. One clip plays at a time across the page, playback only ever
// starts from a click, and the visible button is 40 px inside a 48 px target.

type PlayerState = 'idle' | 'loading' | 'playing' | 'paused' | 'error';

/** The clip that owns the page's one sound. */
let activeElement: HTMLAudioElement | null = null;

function release(element: HTMLAudioElement): void {
  if (activeElement === element) activeElement = null;
}

interface AudioPlayerProps {
  src: string | null;
  /** The commentator, used in the player's accessible name. */
  person: string;
  /** The clip's length, shown before it plays. */
  durationMs?: number | null;
}

/** «0:22» with Western digits, as the board prints it. */
export function clipDuration(durationMs: number | null | undefined): string | null {
  if (!durationMs || durationMs <= 0) return null;
  const total = Math.round(durationMs / 1000);
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
}

export function AudioPlayer({ src, person, durationMs = null }: AudioPlayerProps): ReactElement | null {
  const element = useRef<HTMLAudioElement>(null);
  const [state, setState] = useState<PlayerState>('idle');

  useEffect(() => {
    setState('idle');
  }, [src]);

  // A clip paused by the browser, or by another player, is no longer playing.
  useEffect(() => {
    const media = element.current;
    if (!media) return;
    const onPause = (): void => setState((current) => (current === 'playing' ? 'paused' : current));
    const onWaiting = (): void => setState((current) => (current === 'playing' ? 'loading' : current));
    const onError = (): void => {
      setState('error');
      release(media);
    };
    media.addEventListener('pause', onPause);
    media.addEventListener('waiting', onWaiting);
    media.addEventListener('error', onError);
    return () => {
      media.removeEventListener('pause', onPause);
      media.removeEventListener('waiting', onWaiting);
      media.removeEventListener('error', onError);
    };
  }, [src]);

  const toggle = useCallback(async () => {
    const media = element.current;
    if (!media) return;
    if (state === 'playing') {
      media.pause();
      setState('paused');
      return;
    }
    if (activeElement && activeElement !== media) activeElement.pause();
    activeElement = media;
    setState('loading');
    try {
      await media.play();
      setState('playing');
    } catch {
      release(media);
      setState('error');
    }
  }, [state]);

  if (src === null) return null;

  const label =
    state === 'playing' ? copy.pause : state === 'loading' ? copy.loading : state === 'error' ? copy.error : copy.play;

  return (
    <div
      data-testid="audio-player"
      data-state={state}
      className="flex min-w-0 items-center gap-3 rounded-lg bg-bg px-3 py-2"
    >
      <audio ref={element} src={src} preload="none" aria-label={copy.name(person)} />

      <button
        type="button"
        aria-label={label}
        aria-busy={state === 'loading' || undefined}
        onClick={() => void toggle()}
        className={clsx(
          'inline-flex size-12 flex-none items-center justify-center rounded-pill text-on-accent',
          state === 'error' ? 'bg-error-container text-error' : 'bg-accent',
          focusRing,
        )}
      >
        <span
          aria-hidden="true"
          className={clsx(
            'inline-flex size-10 items-center justify-center rounded-pill',
            state === 'error' ? 'bg-error-container' : 'bg-accent',
          )}
        >
          {state === 'loading' ? (
            <span data-spinner className="size-3 rounded-pill border-2 border-current border-e-transparent motion-safe:animate-spin" />
          ) : (
            <Icon name={state === 'playing' ? 'pause' : state === 'error' ? 'alert' : 'play'} size="lg" />
          )}
        </span>
      </button>

      {/* The waveform is decoration: the state and the time carry the meaning. */}
      <span aria-hidden="true" data-testid="audio-waveform" className="flex h-6 min-w-0 flex-1 items-end gap-1">
        {[30, 60, 45, 80, 55, 90, 40, 70, 35, 65, 85, 50].map((height, index) => (
          <span
            key={index}
            data-on={state === 'playing' && index < 6 ? true : undefined}
            className={clsx('w-full rounded-pill', state === 'playing' ? 'bg-accent' : 'bg-surface-3')}
            style={{ height: `${height}%` }}
          />
        ))}
      </span>

      {state === 'error' ? (
        <span className="flex min-w-0 flex-col gap-1">
          <span role="alert" className="text-caption font-semibold text-error">
            {copy.error}
          </span>
          <button
            type="button"
            onClick={() => void toggle()}
            className={clsx('text-caption self-start font-semibold text-accent-text underline', focusRing)}
          >
            {common.retry}
          </button>
        </span>
      ) : (
        <span dir="ltr" className="text-micro flex-none tabular-nums text-text-tertiary">
          {clipDuration(durationMs) ?? '--:--'}
        </span>
      )}
    </div>
  );
}
