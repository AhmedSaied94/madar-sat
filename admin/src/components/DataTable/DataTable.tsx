import { clsx } from 'clsx';
import { cva } from 'class-variance-authority';
import {
  useEffect,
  useMemo,
  useRef,
  useState,
  type InputHTMLAttributes,
  type KeyboardEvent,
  type ReactElement,
  type ReactNode,
} from 'react';

import { table as copy } from '../../i18n/ar';
import { focusRing } from '../focus';
import { Icon } from '../Icon/Icon';

// The admin's dense, keyboard-first table (DataTable README): sortable header, group rows,
// row actions on hover or focus, bulk selection with the bulk bar, warning rows, locked markers,
// skeleton and empty states. Keys on a focused row: J/↓ next, K/↑ previous, X select, E/Enter edit.

export interface DataTableColumn<Row> {
  id: string;
  header: string;
  cell: (row: Row) => ReactNode;
  /** Makes the column sortable. */
  sortValue?: (row: Row) => string | number;
  /** Tabular, end-aligned numbers. */
  numeric?: boolean;
}

export interface DataTableRowState {
  /** Why the row needs attention, e.g. «بلا قنوات». */
  warning?: string;
  /** An editor's value the importer will not overwrite. */
  locked?: boolean;
}

interface DataTableProps<Row> {
  label: string;
  columns: readonly DataTableColumn<Row>[];
  rows: readonly Row[];
  rowKey: (row: Row) => string;
  /** Names the row in its checkbox label. */
  rowLabel?: (row: Row) => string;
  /** A stable test id per row, for a screen's own assertions. */
  rowTestId?: (row: Row) => string;
  /** Group label, e.g. the competition. Groups keep the order in which they first appear. */
  groupBy?: (row: Row) => string;
  selectable?: boolean;
  bulkActions?: (selectedKeys: readonly string[]) => ReactNode;
  onSelectionChange?: (selectedKeys: readonly string[]) => void;
  rowState?: (row: Row) => DataTableRowState;
  rowActions?: (row: Row) => ReactNode;
  onEdit?: (row: Row) => void;
  loading?: boolean;
  emptyMessage?: string;
  /**
   * Bumped by the screen after a bulk action succeeds: the shared table's selection belongs to the
   * table, so the screen asks it to clear instead of reaching into its state.
   */
  selectionResetKey?: number;
}

type SortDirection = 'ascending' | 'descending';

interface SortState {
  columnId: string;
  direction: SortDirection;
}

interface RowGroup<Row> {
  label: string | null;
  rows: readonly Row[];
}

const SKELETON_ROWS = 5;

const rowStyles = cva(`group ${focusRing}`, {
  variants: {
    tone: {
      default: 'hover:bg-surface-2',
      selected: 'bg-accent-container',
      warning: 'bg-postponed-container',
    },
  },
});

const edgeStyles = cva('border-s-2', {
  variants: {
    tone: {
      default: 'border-s-transparent',
      selected: 'border-s-accent',
      warning: 'border-s-postponed',
    },
  },
});

const cellBase = 'text-label h-12 whitespace-nowrap border-b border-divider px-3';

function compareBy<Row>(sortValue: (row: Row) => string | number, direction: SortDirection) {
  return (a: Row, b: Row): number => {
    const x = sortValue(a);
    const y = sortValue(b);
    const order = typeof x === 'number' && typeof y === 'number' ? x - y : String(x).localeCompare(String(y), 'ar');
    return direction === 'ascending' ? order : -order;
  };
}

function arrange<Row>(
  rows: readonly Row[],
  groupBy: ((row: Row) => string) | undefined,
  sortValue: ((row: Row) => string | number) | undefined,
  direction: SortDirection,
): RowGroup<Row>[] {
  const groups = new Map<string | null, Row[]>();
  for (const row of rows) {
    const key = groupBy ? groupBy(row) : null;
    groups.set(key, [...(groups.get(key) ?? []), row]);
  }
  return [...groups].map(([label, members]) => ({
    label,
    rows: sortValue ? [...members].sort(compareBy(sortValue, direction)) : members,
  }));
}

function Checkbox(props: Omit<InputHTMLAttributes<HTMLInputElement>, 'type' | 'className'> & { indeterminate?: boolean }): ReactElement {
  const { indeterminate = false, ...inputProps } = props;
  const ref = useRef<HTMLInputElement>(null);
  useEffect(() => {
    if (ref.current) ref.current.indeterminate = indeterminate;
  }, [indeterminate]);

  return (
    <span className="relative inline-flex">
      <input
        ref={ref}
        type="checkbox"
        className="peer size-4 cursor-pointer appearance-none rounded-xs ring-2 ring-inset ring-divider-strong checked:bg-accent checked:ring-0 focus-visible:outline-none focus-visible:ring-focus-ring"
        {...inputProps}
      />
      <Icon name="check" size="sm" className="pointer-events-none absolute inset-0 m-auto hidden text-on-accent peer-checked:block" />
    </span>
  );
}

export function DataTable<Row>({
  label,
  columns,
  rows,
  rowKey,
  rowLabel,
  rowTestId,
  groupBy,
  selectable = false,
  bulkActions,
  onSelectionChange,
  rowState,
  rowActions,
  onEdit,
  loading = false,
  emptyMessage,
  selectionResetKey = 0,
}: DataTableProps<Row>): ReactElement {
  const [sort, setSort] = useState<SortState | null>(null);
  const [selected, setSelected] = useState<ReadonlySet<string>>(() => new Set());
  const [activeKey, setActiveKey] = useState<string | null>(null);
  const rowRefs = useRef(new Map<string, HTMLTableRowElement>());

  const sortColumn = sort ? columns.find((column) => column.id === sort.columnId) : undefined;
  const groups = useMemo(
    () => arrange(rows, groupBy, sortColumn?.sortValue, sort?.direction ?? 'ascending'),
    [rows, groupBy, sortColumn, sort?.direction],
  );
  const ordered = useMemo(() => groups.flatMap((group) => group.rows), [groups]);

  // A successful bulk action ends the selection; the screen only says when.
  useEffect(() => {
    setSelected(new Set());
  }, [selectionResetKey]);
  const orderedKeys = useMemo(() => ordered.map(rowKey), [ordered, rowKey]);
  const focusableKey = activeKey !== null && orderedKeys.includes(activeKey) ? activeKey : (orderedKeys[0] ?? null);
  const columnCount = columns.length + (selectable ? 1 : 0) + 1;

  const updateSelection = (next: ReadonlySet<string>): void => {
    setSelected(next);
    onSelectionChange?.([...next]);
  };

  const toggleRow = (key: string): void => {
    const next = new Set(selected);
    if (next.has(key)) next.delete(key);
    else next.add(key);
    updateSelection(next);
  };

  const allSelected = orderedKeys.length > 0 && orderedKeys.every((key) => selected.has(key));
  const someSelected = orderedKeys.some((key) => selected.has(key));

  const toggleSort = (columnId: string): void => {
    setSort((current) =>
      current?.columnId === columnId
        ? { columnId, direction: current.direction === 'ascending' ? 'descending' : 'ascending' }
        : { columnId, direction: 'ascending' },
    );
  };

  const focusRow = (index: number): void => {
    const key = orderedKeys[Math.min(Math.max(index, 0), orderedKeys.length - 1)];
    if (key === undefined) return;
    setActiveKey(key);
    rowRefs.current.get(key)?.focus();
  };

  const onRowKeyDown = (event: KeyboardEvent<HTMLTableRowElement>, row: Row, index: number): void => {
    if (event.target !== event.currentTarget || event.altKey || event.ctrlKey || event.metaKey) return;
    switch (event.key.toLowerCase()) {
      case 'j':
      case 'arrowdown':
        focusRow(index + 1);
        break;
      case 'k':
      case 'arrowup':
        focusRow(index - 1);
        break;
      case 'x':
        if (!selectable) return;
        toggleRow(rowKey(row));
        break;
      case 'e':
      case 'enter':
        if (!onEdit) return;
        onEdit(row);
        break;
      default:
        return;
    }
    event.preventDefault();
  };

  const selectedKeys = orderedKeys.filter((key) => selected.has(key));

  return (
    <div className="flex min-w-0 flex-col">
      {selectable && selectedKeys.length > 0 ? (
        <div
          role="toolbar"
          aria-label={copy.bulkActions}
          className="text-label m-3 flex flex-wrap items-center gap-3 rounded-lg bg-text-primary py-2 pe-2 ps-4 text-text-on-inverse"
        >
          <span className="font-semibold">{copy.selectedCount(selectedKeys.length)}</span>
          <span className="flex-1" />
          {bulkActions?.(selectedKeys)}
        </div>
      ) : null}

      <div className="min-w-0 overflow-x-auto">
        <table aria-busy={loading || undefined} className="w-full border-collapse">
          <caption className="sr-only">{label}</caption>
          <thead>
            <tr>
              {selectable ? (
                <th scope="col" className="w-8 border-b border-divider p-3">
                  <Checkbox
                    aria-label={copy.selectAll}
                    checked={allSelected}
                    indeterminate={someSelected && !allSelected}
                    disabled={loading || orderedKeys.length === 0}
                    onChange={() => updateSelection(allSelected ? new Set() : new Set(orderedKeys))}
                  />
                </th>
              ) : null}
              {columns.map((column) => {
                const direction = sort?.columnId === column.id ? sort.direction : 'none';
                return (
                  <th
                    key={column.id}
                    scope="col"
                    aria-sort={column.sortValue ? direction : undefined}
                    className={clsx(
                      'text-caption whitespace-nowrap border-b p-3 border-divider font-semibold text-text-tertiary',
                      column.numeric ? 'text-end' : 'text-start',
                    )}
                  >
                    {column.sortValue ? (
                      <button
                        type="button"
                        onClick={() => toggleSort(column.id)}
                        className={`inline-flex items-center gap-1 rounded-xs hover:text-text-primary ${focusRing}`}
                      >
                        {column.header}
                        <Icon name="sort" size="sm" />
                      </button>
                    ) : (
                      column.header
                    )}
                  </th>
                );
              })}
              <th scope="col" className="border-b border-divider p-3">
                <span className="sr-only">{copy.rowActions}</span>
              </th>
            </tr>
          </thead>

          {loading ? (
            <tbody>
              <tr className="sr-only">
                <td colSpan={columnCount}>{copy.loading}</td>
              </tr>
              {Array.from({ length: SKELETON_ROWS }, (_, index) => (
                <tr key={index} data-testid="skeleton-row" aria-hidden="true">
                  {Array.from({ length: columnCount }, (__, cell) => (
                    <td key={cell} className={cellBase}>
                      <div className="h-3 w-full rounded-xs bg-surface-2 motion-safe:animate-pulse" />
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          ) : ordered.length === 0 ? (
            <tbody>
              <tr>
                <td colSpan={columnCount} className="text-body py-12 text-center text-text-secondary">
                  {emptyMessage ?? copy.empty}
                </td>
              </tr>
            </tbody>
          ) : (
            groups.map((group) => (
              <tbody key={group.label ?? ''}>
                {group.label !== null ? (
                  <tr>
                    <th
                      scope="colgroup"
                      colSpan={columnCount}
                      className="text-caption border-b border-divider bg-bg px-3 py-2 text-start font-semibold text-text-secondary"
                    >
                      {group.label}
                      <span className="text-micro ms-2 inline-flex h-5 items-center rounded-pill bg-surface-3 px-2 tabular-nums text-text-secondary">
                        {group.rows.length}
                      </span>
                    </th>
                  </tr>
                ) : null}
                {group.rows.map((row) => {
                  const key = rowKey(row);
                  const index = orderedKeys.indexOf(key);
                  const state = rowState?.(row) ?? {};
                  const isSelected = selected.has(key);
                  const tone = isSelected ? 'selected' : state.warning ? 'warning' : 'default';
                  const [firstColumn, ...otherColumns] = columns;

                  return (
                    <tr
                      key={key}
                      ref={(element) => {
                        if (element) rowRefs.current.set(key, element);
                        else rowRefs.current.delete(key);
                      }}
                      data-row-key={key}
                      data-testid={rowTestId?.(row)}
                      data-selected={isSelected || undefined}
                      data-warning={state.warning ? true : undefined}
                      tabIndex={key === focusableKey ? 0 : -1}
                      onFocus={() => setActiveKey(key)}
                      onKeyDown={(event) => onRowKeyDown(event, row, index)}
                      className={rowStyles({ tone })}
                    >
                      {selectable ? (
                        <td className={clsx(cellBase, edgeStyles({ tone }))}>
                          <Checkbox
                            aria-label={rowLabel ? copy.selectNamed(rowLabel(row)) : copy.selectRow}
                            checked={isSelected}
                            onChange={() => toggleRow(key)}
                          />
                        </td>
                      ) : null}
                      {firstColumn ? (
                        <td className={clsx(cellBase, !selectable && edgeStyles({ tone }), firstColumn.numeric && 'text-end tabular-nums')}>
                          {state.warning ? <span className="sr-only">{state.warning}</span> : null}
                          {firstColumn.cell(row)}
                        </td>
                      ) : null}
                      {otherColumns.map((column) => (
                        <td key={column.id} className={clsx(cellBase, column.numeric && 'text-end tabular-nums')}>
                          {column.cell(row)}
                        </td>
                      ))}
                      <td className={clsx(cellBase, 'text-end')}>
                        <div className="flex items-center justify-end gap-1">
                          {state.locked ? (
                            <span className="inline-flex text-postponed">
                              <Icon name="lock" label={copy.locked} />
                            </span>
                          ) : null}
                          {rowActions ? (
                            <div
                              data-testid="row-actions"
                              className="flex items-center gap-1 opacity-0 transition-opacity group-focus-within:opacity-100 group-hover:opacity-100"
                            >
                              {rowActions(row)}
                            </div>
                          ) : null}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            ))
          )}
        </table>
      </div>
    </div>
  );
}
