import { render, screen, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';

import { DiffView, type ConflictChange } from './DiffView';

// The diff extracted from `ConflictDialog` (contract admin-screens, top): `ConflictDialog` keeps
// `stacked` and its own tests stay unchanged; A17 asks for `columns`, the قبل / بعد grid the audit
// board draws. Both take the same `changes`, and neither may throw on a shape it doesn't know.

const changes: ConflictChange[] = [
  { field: 'frequency.mhz', label: 'التردد', before: '11766', after: '11013' },
  { field: 'locked_fields', label: 'الحقول المقفلة', before: '[]', after: '["frequency"]' },
  { field: 'frequency_changed_at', label: 'وقت تغيير التردد', before: '2026-09-02', after: '2026-10-28' },
];

describe('DiffView in columns', () => {
  it('shows the two headings and each value on its own side', () => {
    render(<DiffView changes={changes} layout="columns" />);

    const grid = screen.getByTestId('diff');
    expect(within(grid).getByText('قبل')).toBeInTheDocument();
    expect(within(grid).getByText('بعد')).toBeInTheDocument();

    const before = within(grid).getByTestId('diff-before');
    const after = within(grid).getByTestId('diff-after');

    for (const change of changes) {
      expect(within(before).getByText(String(change.before))).toBeInTheDocument();
      expect(within(after).getByText(String(change.after))).toBeInTheDocument();
    }
  });

  it('keeps each field key beside its values, in mono LTR', () => {
    render(<DiffView changes={changes} layout="columns" />);

    const grid = screen.getByTestId('diff');
    expect(within(grid).getAllByText('frequency.mhz')[0]).toHaveAttribute('dir', 'ltr');
  });

  it('renders nothing for an empty change list', () => {
    render(<DiffView changes={[]} layout="columns" />);

    expect(screen.getByTestId('diff')).toBeEmptyDOMElement();
  });
});

describe('DiffView stacked', () => {
  it('keeps the dialog’s − and + lines', () => {
    render(<DiffView changes={[{ field: 'frequency.mhz', label: 'التردد', before: '11766', after: '11013' }]} layout="stacked" />);

    const grid = screen.getByTestId('diff');
    expect(within(grid).getByText('−')).toBeInTheDocument();
    expect(within(grid).getByText('+')).toBeInTheDocument();
    expect(within(grid).getByTestId('diff-before')).toHaveTextContent('11766');
    expect(within(grid).getByTestId('diff-after')).toHaveTextContent('11013');
  });

  it('shows a missing side as an em dash, never as an empty cell', () => {
    render(<DiffView changes={[{ field: 'frequency', label: 'التردد', before: null, after: '11013' }]} layout="stacked" />);

    expect(screen.getByTestId('diff-before')).toHaveTextContent('—');
  });
});
