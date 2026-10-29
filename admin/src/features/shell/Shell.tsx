import { useEffect, useRef, type ReactElement } from 'react';
import { Outlet, useLocation } from 'react-router-dom';

import { Icon } from '../../components/Icon/Icon';
import { SidebarNav, type SidebarUser } from '../../components/SidebarNav/SidebarNav';
import { RoleChip } from '../../components/StatusChip/StatusChip';
import { shell } from '../../i18n/ar';
import { activeSection, navigation } from './navigation';

interface ShellProps {
  user: SidebarUser;
  onLogout: () => void;
}

// A0: the sidebar on the right (first in the RTL row), a top bar with global search and the
// signed-in user, and the routed page in the content area (admin board "A2 Dashboard in the A0 shell").
export function Shell({ user, onLogout }: ShellProps): ReactElement {
  const { pathname } = useLocation();
  const searchRef = useRef<HTMLInputElement>(null);

  // Ctrl K (⌘K on macOS) searches everywhere (DataTable README).
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent): void => {
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault();
        searchRef.current?.focus();
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, []);

  return (
    <div data-testid="shell" className="flex min-h-screen bg-bg text-text-primary">
      <SidebarNav groups={navigation} active={activeSection(pathname)} user={user} onLogout={onLogout} />

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex flex-wrap items-center gap-3 border-b border-divider px-6 py-3">
          <label className="text-label flex w-full max-w-list-pane-width items-center gap-3 rounded-lg bg-surface-1 px-3 py-2 text-text-tertiary ring-1 ring-inset ring-divider focus-within:ring-2 focus-within:ring-focus-ring">
            <Icon name="search" />
            <input
              ref={searchRef}
              type="search"
              aria-label={shell.searchLabel}
              placeholder={shell.searchPlaceholder}
              className="min-w-0 flex-1 bg-transparent text-text-primary outline-none placeholder:text-text-tertiary"
            />
            <kbd dir="ltr" className="text-micro rounded-xs px-2 py-1 font-mono text-text-tertiary ring-1 ring-inset ring-divider-strong">
              {shell.searchShortcut}
            </kbd>
          </label>

          <div role="group" aria-label={shell.userLabel} className="ms-auto flex items-center gap-3">
            <RoleChip role={user.role} />
            <span className="text-label font-semibold">{user.name}</span>
          </div>
        </header>

        <main className="flex min-w-0 flex-1 flex-col gap-4 px-6 pb-8 pt-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
