import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { renderRtl } from '../../test/render';
import { AudioPlayer } from './AudioPlayer';

// jsdom has no media pipeline: play()/pause() are replaced, and the tests fire the events a browser
// would fire, so the component's five states are exercised for real.

const played: HTMLMediaElement[] = [];
const paused: HTMLMediaElement[] = [];

beforeEach(() => {
  played.length = 0;
  paused.length = 0;
  vi.spyOn(window.HTMLMediaElement.prototype, 'play').mockImplementation(function (this: HTMLMediaElement) {
    played.push(this);
    return Promise.resolve();
  });
  vi.spyOn(window.HTMLMediaElement.prototype, 'pause').mockImplementation(function (this: HTMLMediaElement) {
    paused.push(this);
  });
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe('AudioPlayer', () => {
  it('renders nothing when the commentator has no clip', () => {
    const { container } = renderRtl(<AudioPlayer src={null} person="حفيظ دراجي" />);

    expect(container.querySelector('audio')).toBeNull();
    expect(screen.queryByRole('button')).not.toBeInTheDocument();
  });

  it('starts on a click, never on its own, and shows pause while playing', async () => {
    renderRtl(<AudioPlayer src="https://media.example/clip.mp3" person="حفيظ دراجي" durationMs={22000} />);

    expect(played).toHaveLength(0);
    const button = screen.getByRole('button', { name: 'تشغيل المقطع' });
    expect(button).toBeInTheDocument();
    expect(screen.getByText('0:22')).toBeInTheDocument();

    await userEvent.click(button);

    expect(played).toHaveLength(1);
    expect(await screen.findByRole('button', { name: 'إيقاف المقطع مؤقتاً' })).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'إيقاف المقطع مؤقتاً' }));
    expect(paused).toHaveLength(1);
    expect(screen.getByRole('button', { name: 'تشغيل المقطع' })).toBeInTheDocument();
  });

  it('plays one clip at a time across the page', async () => {
    const { container } = renderRtl(
      <div>
        <AudioPlayer src="https://media.example/a.mp3" person="حفيظ دراجي" />
        <AudioPlayer src="https://media.example/b.mp3" person="عصام عبده" />
      </div>,
    );
    const [first, second] = Array.from(container.querySelectorAll('audio'));
    if (!first || !second) throw new Error('expected two players');

    await userEvent.click(screen.getAllByRole('button', { name: 'تشغيل المقطع' })[0] as HTMLElement);

    expect(played[0]).toBe(first);

    await userEvent.click(screen.getAllByRole('button', { name: 'تشغيل المقطع' })[0] as HTMLElement);
    expect(played[1]).toBe(second);
    // Starting the second clip stops the first: only one sound at a time.
    expect(paused).toContain(first);
  });

  it('shows a busy state while the clip loads', async () => {
    let resolvePlay: (() => void) | undefined;
    vi.spyOn(window.HTMLMediaElement.prototype, 'play').mockImplementation(function (this: HTMLMediaElement) {
      played.push(this);
      return new Promise<void>((resolve) => {
        resolvePlay = resolve;
      });
    });

    renderRtl(<AudioPlayer src="https://media.example/a.mp3" person="عصام عبده" />);
    await userEvent.click(screen.getByRole('button', { name: 'تشغيل المقطع' }));

    const busy = screen.getByRole('button', { name: 'جارٍ تحميل المقطع' });
    expect(busy).toHaveAttribute('aria-busy', 'true');

    resolvePlay?.();
    expect(await screen.findByRole('button', { name: 'إيقاف المقطع مؤقتاً' })).toBeInTheDocument();
  });

  it('says the clip could not be played and offers a retry', async () => {
    const { container } = renderRtl(<AudioPlayer src="https://media.example/broken.mp3" person="بلال علام" />);
    const audio = container.querySelector('audio');
    if (!audio) throw new Error('expected an audio element');

    audio.dispatchEvent(new Event('error'));

    expect(await screen.findByText('تعذّر تشغيل المقطع')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'إعادة المحاولة' }));
    await waitFor(() => expect(played).toHaveLength(1));
  });
});
