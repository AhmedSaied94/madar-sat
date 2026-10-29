import { clsx } from 'clsx';
import { cva } from 'class-variance-authority';
import type { ReactElement } from 'react';
import { Link } from 'react-router-dom';

import { roles, sidebar } from '../../i18n/ar';
import { BrandLockup } from '../BrandMark/BrandMark';
import { focusRing } from '../focus';
import { Icon, type IconName } from '../Icon/Icon';
import type { AdminRoleName } from '../StatusChip/StatusChip';

// The admin's right-hand navigation (SidebarNav README): brand, grouped sections,
// counts of work waiting, V2-marked planned sections, and the signed-in user.

export type SidebarCountTone = 'neutral' | 'waiting' | 'failing';

export interface SidebarNavItem {
  id: string;
  label: string;
  icon: IconName;
  to: string;
  /** Work waiting (matches without channels, failing sources), never totals. */
  count?: { value: number; tone: SidebarCountTone };
  /** A V2 section: visible, but marked so editors know the plan. */
  planned?: boolean;
}

export interface SidebarNavGroup {
  id: string;
  label?: string;
  items: readonly SidebarNavItem[];
}

export interface SidebarUser {
  name: string;
  role: AdminRoleName;
}

interface SidebarNavProps {
  groups: readonly SidebarNavGroup[];
  active: string;
  user: SidebarUser;
  onLogout: () => void;
}

const itemStyles = cva(`text-label flex items-center gap-3 rounded-md px-3 py-2 ${focusRing}`, {
  variants: {
    active: {
      true: 'bg-accent-container font-semibold text-text-primary',
      false: 'text-text-secondary hover:bg-surface-2 hover:text-text-primary',
    },
  },
});

const countStyles = cva('text-micro ms-auto inline-flex h-5 items-center rounded-pill px-2 tabular-nums', {
  variants: {
    tone: {
      neutral: 'bg-surface-3 text-text-secondary',
      waiting: 'bg-postponed-container text-postponed',
      failing: 'bg-error-container text-error',
    },
  },
});

const countToneLabel: Record<SidebarCountTone, string> = {
  neutral: sidebar.countNeutral,
  waiting: sidebar.countWaiting,
  failing: sidebar.countFailing,
};

const initials = (name: string): string =>
  name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((word) => word.charAt(0))
    .join(' ');

function NavItem({ item, active }: { item: SidebarNavItem; active: boolean }): ReactElement {
  return (
    <li>
      <Link to={item.to} data-label={item.label} aria-current={active ? 'page' : undefined} className={itemStyles({ active })}>
        <Icon name={item.icon} size="lg" className={clsx(active && 'text-accent-text')} />
        <span>{item.label}</span>
        {item.planned ? (
          <span className="text-micro ms-auto rounded-xs px-1 font-mono text-text-tertiary ring-1 ring-inset ring-divider-strong">
            {sidebar.plannedTag}
            <span className="sr-only"> {sidebar.plannedHint}</span>
          </span>
        ) : null}
        {item.count ? (
          <span data-testid="nav-count" data-tone={item.count.tone} className={countStyles({ tone: item.count.tone })}>
            {item.count.value}
            <span className="sr-only"> {countToneLabel[item.count.tone]}</span>
          </span>
        ) : null}
      </Link>
    </li>
  );
}

export function SidebarNav({ groups, active, user, onLogout }: SidebarNavProps): ReactElement {
  return (
    <aside className="sticky top-0 flex h-screen w-admin-sidebar-width shrink-0 flex-col gap-1 border-e border-divider bg-surface-1 px-3 pb-4 pt-5">
      <div className="px-2 pb-4">
        <BrandLockup />
      </div>

      {/* Only the list scrolls on short screens; the brand and the signed-in footer stay put. */}
      <nav aria-label={sidebar.label} className="flex min-h-0 flex-1 flex-col overflow-y-auto">
        {groups.map((group) => {
          const headingId = `sidebar-group-${group.id}`;
          return (
            <div key={group.id} className="flex flex-col">
              {group.label ? (
                <h2 id={headingId} className="text-micro px-3 pb-2 pt-4 text-text-tertiary">
                  {group.label}
                </h2>
              ) : null}
              <ul aria-labelledby={group.label ? headingId : undefined} className="flex flex-col gap-1">
                {group.items.map((item) => (
                  <NavItem key={item.id} item={item} active={item.id === active} />
                ))}
              </ul>
            </div>
          );
        })}
      </nav>

      <div className="mt-auto flex items-center gap-3 border-t border-divider px-2 pt-3">
        <span aria-hidden="true" className="text-micro inline-flex size-8 shrink-0 items-center justify-center rounded-pill bg-surface-3 font-display text-text-secondary">
          {initials(user.name)}
        </span>
        <div className="flex min-w-0 flex-1 flex-col">
          <span className="text-label truncate font-semibold">{user.name}</span>
          <span className="text-caption text-text-tertiary">{roles[user.role]}</span>
        </div>
        <button
          type="button"
          aria-label={sidebar.logout}
          onClick={onLogout}
          className={`inline-flex size-8 shrink-0 items-center justify-center rounded-pill text-text-secondary hover:bg-surface-2 hover:text-text-primary ${focusRing}`}
        >
          <Icon name="logout" size="lg" />
        </button>
      </div>
    </aside>
  );
}
