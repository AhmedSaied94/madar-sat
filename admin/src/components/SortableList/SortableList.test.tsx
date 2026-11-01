import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';

import { renderRtl } from '../../test/render';
import { SortableList } from './SortableList';

interface Option {
  id: string;
  name: string;
}

const items: Option[] = [
  { id: 'nilesat', name: 'نايل سات' },
  { id: 'hispasat', name: 'هيسباسات' },
  { id: 'hotbird', name: 'هوت بيرد' },
];

function renderList(options: { disabled?: boolean; onReorder?: (keys: readonly string[]) => void } = {}) {
  const onReorder = options.onReorder ?? vi.fn();
  renderRtl(
    <SortableList
      label="الترتيب"
      items={items}
      itemKey={(item) => item.id}
      itemName={(item) => item.name}
      render={(item) => <span>{item.name}</span>}
      onReorder={onReorder}
      disabled={options.disabled ?? false}
      hint="اسحب لإعادة الترتيب"
    />,
  );
  return { onReorder };
}

const handles = () => screen.getAllByRole('button', { name: /إعادة الترتيب$/ });

describe('SortableList', () => {
  it('lists every item in order, numbered, each with a drag handle', () => {
    renderList();

    expect(screen.getByText('اسحب لإعادة الترتيب')).toBeInTheDocument();
    const items_ = screen.getAllByRole('listitem');
    expect(items_).toHaveLength(3);
    expect(items_[0]).toHaveTextContent('1');
    expect(items_[0]).toHaveTextContent('نايل سات');
    expect(items_[2]).toHaveTextContent('3');
    expect(handles()).toHaveLength(3);
    expect(handles()[0]).toHaveAccessibleName('اسحب نايل سات لإعادة الترتيب');
  });

  it('reorders with the keyboard: Space lifts, ArrowDown moves, Space drops', async () => {
    const { onReorder } = renderList();
    const first = handles()[0];
    if (!first) throw new Error('expected a handle');

    first.focus();
    await userEvent.keyboard('[Space]');
    expect(screen.getByTestId("sortable-status")).toHaveTextContent('التقطت نايل سات');

    await userEvent.keyboard('[ArrowDown]');
    expect(screen.getByTestId("sortable-status")).toHaveTextContent('نُقل نايل سات إلى الترتيب 2');
    const preview = screen.getAllByRole('listitem');
    expect(preview[0]).toHaveTextContent('هيسباسات');
    expect(preview[1]).toHaveTextContent('نايل سات');

    await userEvent.keyboard('[Space]');
    expect(onReorder).toHaveBeenCalledWith(['hispasat', 'nilesat', 'hotbird']);
    expect(screen.getByTestId("sortable-status")).toHaveTextContent('أُفلت نايل سات في الترتيب 2');
  });

  it('moves up with ArrowUp and cancels with Escape without saving', async () => {
    const { onReorder } = renderList();
    const second = handles()[1];
    if (!second) throw new Error('expected a handle');

    second.focus();
    await userEvent.keyboard('[Enter]');
    await userEvent.keyboard('[ArrowUp]');
    expect(screen.getAllByRole('listitem')[0]).toHaveTextContent('هيسباسات');

    await userEvent.keyboard('[Escape]');
    expect(onReorder).not.toHaveBeenCalled();
    expect(screen.getByTestId("sortable-status")).toHaveTextContent('أُلغي نقل هيسباسات');
    expect(screen.getAllByRole('listitem')[0]).toHaveTextContent('نايل سات');
  });

  it('is inert while a save is running', async () => {
    const { onReorder } = renderList({ disabled: true });

    const handle = handles()[0];
    expect(handle).toBeDisabled();

    handle?.focus();
    await userEvent.keyboard('[Space]');
    expect(onReorder).not.toHaveBeenCalled();
  });

  it('marks the open row and names it for assistive tech', () => {
    renderRtl(
      <SortableList
        label="الترتيب"
        items={items}
        itemKey={(item) => item.id}
        itemName={(item) => item.name}
        render={(item) => <span>{item.name}</span>}
        selectedKey="hispasat"
      />,
    );

    const selected = screen.getAllByRole('listitem')[1];
    expect(selected).toHaveAttribute('aria-current', 'true');
    expect(within(selected as HTMLElement).getByText('هيسباسات')).toBeInTheDocument();
  });
});
