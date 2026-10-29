import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';

import { renderRtl } from '../../test/render';
import { DataTable, type DataTableColumn } from './DataTable';

interface MatchRow {
  id: string;
  time: string;
  title: string;
  competition: string;
  channels: number;
  locked?: boolean;
}

const rows: MatchRow[] = [
  { id: 'm1', time: '8:00 م', title: 'فرايبورج × فولفسبورغ', competition: 'كأس ألمانيا', channels: 51 },
  { id: 'm2', time: '10:45 م', title: 'بايرن ميونخ × مجدبرج', competition: 'كأس ألمانيا', channels: 75, locked: true },
  { id: 'm3', time: '8:00 م', title: 'يديلوه × هرتا برلين', competition: 'كأس ألمانيا', channels: 0 },
  { id: 'm4', time: '9:00 م', title: 'ريال مدريد × خيتافي', competition: 'الدوري الإسباني', channels: 12 },
];

const columns: DataTableColumn<MatchRow>[] = [
  { id: 'time', header: 'الوقت', cell: (row) => row.time },
  { id: 'title', header: 'المباراة', cell: (row) => row.title, sortValue: (row) => row.title },
  { id: 'channels', header: 'القنوات', cell: (row) => row.channels, sortValue: (row) => row.channels, numeric: true },
];

interface RenderOptions {
  rows?: MatchRow[];
  loading?: boolean;
  onEdit?: (row: MatchRow) => void;
}

function renderTable({ rows: data = rows, loading = false, onEdit = vi.fn() }: RenderOptions = {}) {
  renderRtl(
    <DataTable
      label="مباريات اليوم"
      columns={columns}
      rows={data}
      rowKey={(row) => row.id}
      rowLabel={(row) => row.title}
      groupBy={(row) => row.competition}
      selectable
      bulkActions={(keys) => <button type="button">حذف {keys.length} مباراة</button>}
      rowState={(row) => ({
        ...(row.channels === 0 ? { warning: 'بلا قنوات' } : {}),
        ...(row.locked ? { locked: true } : {}),
      })}
      rowActions={(row) => (
        <button type="button" aria-label={`تعديل ${row.title}`}>
          تعديل
        </button>
      )}
      onEdit={onEdit}
      loading={loading}
    />,
  );
  return { table: screen.getByRole('table', { name: 'مباريات اليوم' }), onEdit };
}

const dataRows = (table: HTMLElement) => within(table).getAllByRole('row').filter((row) => row.hasAttribute('data-row-key'));
const rowFor = (table: HTMLElement, title: string) => {
  const row = dataRows(table).find((candidate) => candidate.textContent?.includes(title));
  if (!row) throw new Error(`no row for ${title}`);
  return row;
};

describe('DataTable', () => {
  it('sorts a sortable column with a glyph and aria-sort, ascending then descending', async () => {
    const { table } = renderTable();

    const channelsHeader = within(table).getByRole('columnheader', { name: /القنوات/ });
    expect(channelsHeader).toHaveAttribute('aria-sort', 'none');
    expect(within(table).getByRole('columnheader', { name: 'الوقت' })).not.toHaveAttribute('aria-sort');

    await userEvent.click(within(channelsHeader).getByRole('button'));
    expect(channelsHeader).toHaveAttribute('aria-sort', 'ascending');
    expect(dataRows(table).map((row) => row.getAttribute('data-row-key'))).toEqual(['m3', 'm1', 'm2', 'm4']);

    await userEvent.click(within(channelsHeader).getByRole('button'));
    expect(channelsHeader).toHaveAttribute('aria-sort', 'descending');
    expect(dataRows(table).map((row) => row.getAttribute('data-row-key'))).toEqual(['m2', 'm1', 'm3', 'm4']);
  });

  it('groups rows under a competition row with its count', () => {
    const { table } = renderTable();

    const group = within(table).getByRole('rowheader', { name: /كأس ألمانيا/ });
    expect(group).toHaveTextContent('3');
    expect(within(table).getByRole('rowheader', { name: /الدوري الإسباني/ })).toHaveTextContent('1');
  });

  it('reveals row actions on hover and on keyboard focus', () => {
    const { table } = renderTable();

    const row = rowFor(table, 'فرايبورج');
    const actions = within(row).getByTestId('row-actions');
    expect(row).toHaveClass('group', 'hover:bg-surface-2');
    expect(actions).toHaveClass('opacity-0', 'group-hover:opacity-100', 'group-focus-within:opacity-100');
    expect(within(actions).getByRole('button', { name: 'تعديل فرايبورج × فولفسبورغ' })).toBeInTheDocument();
  });

  it('selects rows, shows the bulk bar with the count, and selects all from the header', async () => {
    const { table } = renderTable();
    expect(screen.queryByRole('toolbar')).not.toBeInTheDocument();

    await userEvent.click(screen.getByRole('checkbox', { name: 'تحديد بايرن ميونخ × مجدبرج' }));
    const bar = screen.getByRole('toolbar', { name: 'إجراءات على المحدد' });
    expect(bar).toHaveTextContent('تم تحديد 1');
    expect(within(bar).getByRole('button', { name: 'حذف 1 مباراة' })).toBeInTheDocument();
    expect(rowFor(table, 'بايرن')).toHaveAttribute('data-selected', 'true');
    expect(rowFor(table, 'بايرن')).toHaveClass('bg-accent-container');

    await userEvent.click(screen.getByRole('checkbox', { name: 'تحديد الكل' }));
    expect(screen.getByRole('toolbar')).toHaveTextContent('تم تحديد 4');
  });

  it('flags warning rows with the postponed container and a text reason', () => {
    const { table } = renderTable();

    const row = rowFor(table, 'يديلوه');
    expect(row).toHaveAttribute('data-warning', 'true');
    expect(row).toHaveClass('bg-postponed-container');
    expect(within(row).getByText('بلا قنوات')).toBeInTheDocument();
  });

  it('marks locked rows with a labelled lock glyph', () => {
    const { table } = renderTable();

    expect(within(rowFor(table, 'بايرن')).getByRole('img', { name: 'قيمة مقفلة: لن يغيّرها الاستيراد' })).toBeInTheDocument();
    expect(within(rowFor(table, 'فرايبورج')).queryByRole('img', { name: /قيمة مقفلة/ })).not.toBeInTheDocument();
  });

  it('end-aligns numeric columns with tabular figures', () => {
    const { table } = renderTable();

    const cell = within(rowFor(table, 'فرايبورج')).getByText('51');
    expect(cell.closest('td')).toHaveClass('text-end', 'tabular-nums');
  });

  it('shows skeleton rows while loading', () => {
    const { table } = renderTable({ loading: true });

    expect(table).toHaveAttribute('aria-busy', 'true');
    expect(within(table).getAllByTestId('skeleton-row').length).toBeGreaterThan(0);
    expect(dataRows(table)).toHaveLength(0);
  });

  it('shows the empty state when there are no rows', () => {
    const { table } = renderTable({ rows: [] });

    expect(within(table).getByText('لا توجد بيانات لعرضها')).toBeInTheDocument();
  });

  it('is keyboard-first: J and K move, X selects, E edits', async () => {
    const { table, onEdit } = renderTable();
    const [first, second] = dataRows(table);
    if (!first || !second) throw new Error('expected rows');

    first.focus();
    await userEvent.keyboard('j');
    expect(second).toHaveFocus();
    await userEvent.keyboard('k');
    expect(first).toHaveFocus();

    await userEvent.keyboard('x');
    expect(first).toHaveAttribute('data-selected', 'true');

    await userEvent.keyboard('e');
    expect(onEdit).toHaveBeenCalledWith(rows[0]);
  });
});
