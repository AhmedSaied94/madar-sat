import { closestCenter, DndContext, PointerSensor, useSensor, useSensors, type DragEndEvent } from '@dnd-kit/core';
import { SortableContext, useSortable, verticalListSortingStrategy } from '@dnd-kit/sortable';
import { clsx } from 'clsx';
import { useEffect, useState, type CSSProperties, type KeyboardEvent, type ReactElement, type ReactNode } from 'react';

import { sortable as copy } from '../../i18n/ar';
import { focusRing } from '../focus';
import { Icon } from '../Icon/Icon';

// Reorderable admin lists (A6 and A7, from ListRow's ordered variant): a drag handle for the mouse,
// and a keyboard path of its own — Space or Enter lifts, the two arrows move, Space drops and Escape
// cancels — so the order is usable without a pointer. Every step is announced in Arabic.

export interface SortableListProps<Item> {
  /** Names the list, e.g. «الترتيب». */
  label: string;
  items: readonly Item[];
  itemKey: (item: Item) => string;
  /** The item's name in the handle's label and in the announcements. */
  itemName: (item: Item) => string;
  render: (item: Item) => ReactNode;
  /** The complete new key order, top first. */
  onReorder?: (keys: readonly string[]) => void;
  /** While a save is running the handles are inert. */
  disabled?: boolean;
  hint?: string;
  /** Marks the row whose editor is open. */
  selectedKey?: string | null;
}

interface SortableRowProps {
  id: string;
  position: number;
  name: string;
  selected: boolean;
  disabled: boolean;
  children: ReactNode;
  onKeyDown: (event: KeyboardEvent<HTMLButtonElement>) => void;
}

function SortableRow({ id, position, name, selected, disabled, children, onKeyDown }: SortableRowProps): ReactElement {
  const { attributes, listeners, setNodeRef, setActivatorNodeRef, transform, transition, isDragging } = useSortable({
    id,
    disabled,
  });

  // dnd-kit hands back a transform object; the row follows the pointer with it.
  const style: CSSProperties | undefined = transform
    ? { transform: `translate3d(${transform.x}px, ${transform.y}px, 0)`, transition }
    : { transition };

  return (
    <li
      ref={setNodeRef}
      style={style}
      data-row-key={id}
      data-dragging={isDragging || undefined}
      aria-current={selected ? 'true' : undefined}
      className={clsx(
        'flex min-h-12 items-center gap-3 rounded-lg bg-surface-1 px-3 py-2',
        selected ? 'ring-2 ring-inset ring-accent' : 'ring-1 ring-inset ring-divider',
        isDragging && 'shadow-raised',
      )}
    >
      <button
        {...attributes}
        {...listeners}
        ref={setActivatorNodeRef}
        type="button"
        disabled={disabled}
        aria-label={copy.handle(name)}
        onKeyDown={onKeyDown}
        className={clsx(
          'inline-flex size-12 flex-none items-center justify-center rounded-md text-text-tertiary hover:bg-surface-2 hover:text-text-primary disabled:cursor-not-allowed disabled:text-text-disabled',
          focusRing,
        )}
      >
        <Icon name="grip" size="lg" />
      </button>
      <span aria-hidden="true" className="text-caption w-6 shrink-0 text-center tabular-nums text-text-tertiary">
        {position}
      </span>
      <div className="flex min-w-0 flex-1 items-center gap-3">{children}</div>
    </li>
  );
}

export function SortableList<Item>({
  label,
  items,
  itemKey,
  itemName,
  render,
  onReorder,
  disabled = false,
  hint,
  selectedKey = null,
}: SortableListProps<Item>): ReactElement {
  const declared = items.map(itemKey);
  const [order, setOrder] = useState<readonly string[]>(declared);
  const [lifted, setLifted] = useState<string | null>(null);
  const [message, setMessage] = useState('');

  // A refetch replaces the rows; while the editor is lifting one, its own working order wins.
  useEffect(() => {
    if (lifted === null) setOrder(items.map(itemKey));
  }, [items, itemKey, lifted]);

  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 4 } }));
  const byKey = new Map(items.map((item) => [itemKey(item), item]));
  const ordered = order.flatMap((key) => {
    const item = byKey.get(key);
    return item === undefined ? [] : [item];
  });

  function commitOrder(next: readonly string[]): void {
    setOrder(next);
    setLifted(null);
    onReorder?.(next);
  }

  const itemNameOf = (key: string): string => {
    const item = byKey.get(key);
    return item === undefined ? key : itemName(item);
  };

  /** Moves the lifted row one place and says where it landed. */
  function move(key: string, delta: number): void {
    const current = order.indexOf(key);
    const target = current + delta;
    if (current === -1 || target < 0 || target >= order.length) return;
    const next = [...order];
    const [moved] = next.splice(current, 1);
    if (moved === undefined) return;
    next.splice(target, 0, moved);
    setOrder(next);
    setMessage(copy.moved(itemNameOf(key), target + 1));
  }

  function onHandleKeyDown(event: KeyboardEvent<HTMLButtonElement>, key: string): void {
    if (disabled) return;
    const name = itemNameOf(key);
    if (event.key === ' ' || event.key === 'Enter') {
      event.preventDefault();
      if (lifted === key) {
        const position = order.indexOf(key) + 1;
        setMessage(copy.dropped(name, position));
        commitOrder(order);
      } else {
        setLifted(key);
        setMessage(copy.lifted(name));
      }
      return;
    }
    if (lifted !== key) return;
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      move(key, 1);
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      move(key, -1);
    } else if (event.key === 'Escape') {
      event.preventDefault();
      setOrder(declared);
      setLifted(null);
      setMessage(copy.cancelled(name));
    }
  }

  function onDragEnd(event: DragEndEvent): void {
    const { active, over } = event;
    if (!over || active.id === over.id) return;
    const from = order.indexOf(String(active.id));
    const to = order.indexOf(String(over.id));
    if (from === -1 || to === -1) return;
    const next = [...order];
    const [moved] = next.splice(from, 1);
    if (moved === undefined) return;
    next.splice(to, 0, moved);
    setOrder(next);
    setMessage(copy.dropped(itemNameOf(moved), to + 1));
    onReorder?.(next);
  }

  return (
    <div className="flex min-w-0 flex-col gap-2">
      <div className="flex items-center gap-2">
        <h2 className="text-caption font-semibold text-text-secondary">{label}</h2>
        {hint ? <span className="text-caption text-text-tertiary">{hint}</span> : null}
        {disabled ? <span className="text-caption text-text-tertiary">{copy.saving}</span> : null}
      </div>

      <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onDragEnd}>
        <SortableContext items={[...order]} strategy={verticalListSortingStrategy}>
          <ul aria-label={label} className="flex flex-col gap-2">
            {ordered.map((item, index) => {
              const key = itemKey(item);
              return (
                <SortableRow
                  key={key}
                  id={key}
                  position={index + 1}
                  name={itemName(item)}
                  selected={key === selectedKey}
                  disabled={disabled}
                  onKeyDown={(event) => onHandleKeyDown(event, key)}
                >
                  {render(item)}
                </SortableRow>
              );
            })}
          </ul>
        </SortableContext>
      </DndContext>

      <p data-testid="sortable-status" role="status" aria-live="polite" className="sr-only">
        {message}
      </p>
    </div>
  );
}
