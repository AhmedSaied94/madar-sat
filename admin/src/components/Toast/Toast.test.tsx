import { act, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import type { ReactElement } from 'react';
import { describe, expect, it, vi } from 'vitest';

import { renderRtl } from '../../test/render';
import { TOAST_DURATION_MS, ToastProvider, useToast, type ToastOptions } from './Toast';

function Trigger({ options }: { options: ToastOptions }): ReactElement {
  const toast = useToast();
  return (
    <button type="button" onClick={() => toast.show(options)}>
      show
    </button>
  );
}

function renderTrigger(options: ToastOptions) {
  renderRtl(<Trigger options={options} />, { wrapper: ToastProvider });
  return screen.getByRole('button', { name: 'show' });
}

describe('Toast', () => {
  it('announces «تم الحفظ» politely and dismisses it after 2 seconds', () => {
    vi.useFakeTimers();
    const trigger = renderTrigger({ kind: 'success', title: 'تم الحفظ' });

    act(() => trigger.click());
    const region = screen.getByRole('status');
    expect(within(region).getByText('تم الحفظ')).toBeInTheDocument();
    expect(TOAST_DURATION_MS).toBe(2000);

    act(() => vi.advanceTimersByTime(TOAST_DURATION_MS - 1));
    expect(screen.getByText('تم الحفظ')).toBeInTheDocument();
    act(() => vi.advanceTimersByTime(1));
    expect(screen.queryByText('تم الحفظ')).not.toBeInTheDocument();
  });

  it('announces «فشل الحفظ» assertively and keeps it until dismissed', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    const trigger = renderTrigger({ kind: 'error', title: 'فشل الحفظ', description: 'انقطع الاتصال بالخادم' });

    act(() => trigger.click());
    const region = screen.getByRole('alert');
    expect(within(region).getByText('فشل الحفظ')).toBeInTheDocument();

    act(() => vi.advanceTimersByTime(TOAST_DURATION_MS * 5));
    expect(screen.getByText('فشل الحفظ')).toBeInTheDocument();

    await userEvent.click(within(region).getByRole('button', { name: 'إغلاق' }));
    expect(screen.queryByText('فشل الحفظ')).not.toBeInTheDocument();
  });

  it('runs its action and closes', async () => {
    const onRetry = vi.fn();
    const trigger = renderTrigger({ kind: 'error', title: 'فشل الحفظ', action: { label: 'إعادة المحاولة', onClick: onRetry } });

    await userEvent.click(trigger);
    await userEvent.click(screen.getByRole('button', { name: 'إعادة المحاولة' }));

    expect(onRetry).toHaveBeenCalledOnce();
    expect(screen.queryByText('فشل الحفظ')).not.toBeInTheDocument();
  });

  it('animates only when the user allows motion', async () => {
    const trigger = renderTrigger({ kind: 'success', title: 'تم الحفظ' });

    await userEvent.click(trigger);
    const toast = screen.getByText('تم الحفظ').closest('[data-toast]');
    expect(toast).not.toBeNull();
    const animations = [...(toast?.classList ?? [])].filter((name) => name.includes('animate-'));
    expect(animations.length).toBeGreaterThan(0);
    expect(animations.every((name) => name.startsWith('motion-safe:'))).toBe(true);
  });

  it('marks the kind with an icon as well as color', async () => {
    const trigger = renderTrigger({ kind: 'success', title: 'تم الحفظ' });

    await userEvent.click(trigger);
    const toast = screen.getByText('تم الحفظ').closest('[data-toast]');
    expect(toast).toHaveAttribute('data-kind', 'success');
    expect(toast?.querySelector('svg')).not.toBeNull();
  });
});
