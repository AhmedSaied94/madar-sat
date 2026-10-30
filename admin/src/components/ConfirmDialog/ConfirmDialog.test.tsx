import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState, type ReactElement } from 'react';
import { describe, expect, it, vi } from 'vitest';

import { renderRtl } from '../../test/render';
import { ConfirmDialog } from './ConfirmDialog';
import { ConflictDialog } from './ConflictDialog';

function TypedConfirmHarness({ onCancel }: { onCancel: () => void }): ReactElement {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button type="button" onClick={() => setOpen(true)}>
        حذف المحدد
      </button>
      <ConfirmDialog
        open={open}
        title="حذف 20 مباراة؟"
        body="ستُحذف مباريات «كأس ملك إسبانيا» المحددة ليوم 28 أكتوبر، مع قنواتها ومتابعاتها. لا يمكن التراجع."
        phrase="حذف 20"
        confirmLabel="حذف 20 مباراة"
        destructive
        onConfirm={vi.fn()}
        onCancel={() => {
          setOpen(false);
          onCancel();
        }}
      />
    </>
  );
}

describe('ConfirmDialog (typed confirmation)', () => {
  it('keeps the confirm button disabled until the exact phrase is typed', async () => {
    renderRtl(<TypedConfirmHarness onCancel={vi.fn()} />);

    await userEvent.click(screen.getByRole('button', { name: 'حذف المحدد' }));
    const dialog = screen.getByRole('alertdialog', { name: 'حذف 20 مباراة؟' });
    const confirm = within(dialog).getByRole('button', { name: 'حذف 20 مباراة' });
    expect(confirm).toBeDisabled();

    const input = within(dialog).getByLabelText(/للتأكيد اكتب/);
    await userEvent.type(input, 'حذف 2');
    expect(confirm).toBeDisabled();

    await userEvent.type(input, '0');
    expect(confirm).toBeEnabled();
  });

  it('closes on Escape and on cancel, and runs nothing', async () => {
    const onCancel = vi.fn();
    renderRtl(<TypedConfirmHarness onCancel={onCancel} />);

    await userEvent.click(screen.getByRole('button', { name: 'حذف المحدد' }));
    await userEvent.keyboard('{Escape}');
    expect(screen.queryByRole('alertdialog')).not.toBeInTheDocument();
    expect(onCancel).toHaveBeenCalledTimes(1);

    await userEvent.click(screen.getByRole('button', { name: 'حذف المحدد' }));
    await userEvent.click(screen.getByRole('button', { name: 'إلغاء' }));
    expect(screen.queryByRole('alertdialog')).not.toBeInTheDocument();
    expect(onCancel).toHaveBeenCalledTimes(2);
  });

  it('traps focus inside the dialog and gives it back to the trigger', async () => {
    renderRtl(<TypedConfirmHarness onCancel={vi.fn()} />);

    const trigger = screen.getByRole('button', { name: 'حذف المحدد' });
    await userEvent.click(trigger);

    const dialog = screen.getByRole('alertdialog');
    // Never the destructive button first (ConfirmDialog README).
    expect(within(dialog).getByRole('button', { name: 'حذف 20 مباراة' })).not.toHaveFocus();

    for (let index = 0; index < 6; index += 1) {
      await userEvent.tab();
      expect(dialog).toContainElement(document.activeElement as HTMLElement);
    }

    await userEvent.keyboard('{Escape}');
    expect(trigger).toHaveFocus();
  });
});

const changedByAdmin = { kind: 'admin', name: 'يوسف عمر', at: '2026-10-30T14:02:11Z' } as const;
const changedBySource = { kind: 'source', name: 'ysscores', at: '2026-10-30T14:02:11Z' } as const;
const changes = [
  { field: 'competition_stage', label: 'المرحلة', before: 'الجولة 9', after: 'الجولة 9 - الذهاب' },
  { field: 'kickoff_at', label: 'موعد الانطلاق', before: '20:00', after: '21:00' },
];

describe('ConflictDialog (If-Match failed)', () => {
  it('names the admin who saved first, shows the field diff, and reloads', async () => {
    const onReload = vi.fn();
    renderRtl(
      <ConflictDialog
        open
        subject="ميلان × بولونيا"
        changedBy={changedByAdmin}
        changes={changes}
        onReload={onReload}
        onClose={vi.fn()}
      />,
    );

    const dialog = screen.getByRole('alertdialog', { name: 'عدّل يوسف عمر هذا العنصر' });
    expect(dialog).toHaveTextContent('حُفظت نسخة أحدث من «ميلان × بولونيا» في 16:02 بتوقيت القاهرة');

    await userEvent.click(within(dialog).getByRole('button', { name: 'اعرض التغييرات' }));
    const diff = within(dialog).getByTestId('conflict-diff');
    expect(diff).toHaveTextContent('الجولة 9');
    expect(diff).toHaveTextContent('الجولة 9 - الذهاب');
    expect(within(diff).getByText('الجولة 9')).toHaveAttribute('data-change', 'before');
    expect(within(diff).getByText('الجولة 9 - الذهاب')).toHaveAttribute('data-change', 'after');

    await userEvent.click(within(dialog).getByRole('button', { name: 'إعادة التحميل' }));
    expect(onReload).toHaveBeenCalledTimes(1);
  });

  it('names the source when an import saved first', () => {
    renderRtl(
      <ConflictDialog
        open
        subject="ميلان × بولونيا"
        changedBy={changedBySource}
        changes={changes}
        onReload={vi.fn()}
        onClose={vi.fn()}
      />,
    );

    const dialog = screen.getByRole('alertdialog', { name: 'حدّث ysscores هذا العنصر' });
    expect(within(dialog).getByText('ysscores')).toHaveAttribute('dir', 'ltr');
  });
});
