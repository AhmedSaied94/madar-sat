import { screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';

import { renderRtl } from '../../test/render';
import { EmptyState } from './EmptyState';

describe('EmptyState', () => {
  it.each([
    ['empty', 'text-text-secondary'],
    ['error', 'text-error'],
    ['allClear', 'text-free'],
  ] as const)('%s shows the orbit motif, a title and one line of help', (kind, tone) => {
    renderRtl(<EmptyState kind={kind} title="لا توجد مباريات" body="جرّب يوماً آخر." />);

    expect(screen.getByRole('heading', { name: 'لا توجد مباريات' })).toBeInTheDocument();
    expect(screen.getByText('جرّب يوماً آخر.')).toBeInTheDocument();
    expect(screen.getByTestId('empty-state-glyph')).toHaveClass(tone);
    expect(screen.getByTestId('empty-state')).toHaveAttribute('data-kind', kind);
  });

  it('offers at most one action', async () => {
    const onRetry = vi.fn();
    renderRtl(<EmptyState kind="error" title="تعذّر التحميل" body="تحقق من الاتصال." action={{ label: 'إعادة المحاولة', onClick: onRetry }} />);

    await userEvent.click(screen.getByRole('button', { name: 'إعادة المحاولة' }));
    expect(onRetry).toHaveBeenCalledOnce();
    expect(screen.getAllByRole('button')).toHaveLength(1);
  });
});
