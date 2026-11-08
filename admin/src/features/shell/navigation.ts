import type { AdminRoleName } from '../../components/StatusChip/StatusChip';
import type { SidebarNavGroup } from '../../components/SidebarNav/SidebarNav';
import { navGroups, navLabels } from '../../i18n/ar';

// The A0 sidebar, in product doc §10 A0 order. Counts arrive with the dashboard data (D2+); D1 shows none.
// A16 and A17 are admin only (contract admin-screens "Routes and roles"): the shell drops them rather
// than disabling them, because the server refuses them to an editor anyway.
export const navigation: readonly SidebarNavGroup[] = [
  {
    id: 'overview',
    items: [{ id: 'dashboard', label: navLabels.dashboard, icon: 'dashboard', to: '/' }],
  },
  {
    id: 'content',
    label: navGroups.content,
    items: [
      { id: 'matches', label: navLabels.matches, icon: 'ball', to: '/matches' },
      { id: 'teams', label: navLabels.teams, icon: 'shield', to: '/teams' },
      { id: 'competitions', label: navLabels.competitions, icon: 'trophy', to: '/competitions' },
      { id: 'channels', label: navLabels.channels, icon: 'tv', to: '/channels' },
      { id: 'satellites', label: navLabels.satellites, icon: 'satellite', to: '/satellites' },
      { id: 'rightsHolders', label: navLabels.rightsHolders, icon: 'certificate', to: '/rights-holders' },
      { id: 'commentators', label: navLabels.commentators, icon: 'mic', to: '/commentators' },
      { id: 'feeds', label: navLabels.feeds, icon: 'tower', to: '/feeds' },
      { id: 'lists', label: navLabels.lists, icon: 'layers', to: '/lists' },
    ],
  },
  {
    id: 'operations',
    label: navGroups.operations,
    items: [
      { id: 'sources', label: navLabels.sources, icon: 'database', to: '/sources' },
      { id: 'reports', label: navLabels.reports, icon: 'flag', to: '/reports', planned: true },
      { id: 'notifications', label: navLabels.notifications, icon: 'bell', to: '/notifications' },
    ],
  },
  {
    id: 'administration',
    label: navGroups.administration,
    items: [
      { id: 'users', label: navLabels.users, icon: 'users', to: '/users', adminOnly: true },
      { id: 'audit', label: navLabels.audit, icon: 'history', to: '/audit', adminOnly: true },
    ],
  },
];

/** The sidebar a signed-in account gets: an editor keeps everything except the admin-only sections. */
export function navigationFor(role: AdminRoleName): readonly SidebarNavGroup[] {
  if (role === 'admin') return navigation;
  return navigation
    .map((group) => ({ ...group, items: group.items.filter((item) => item.adminOnly !== true) }))
    .filter((group) => group.items.length > 0);
}

/** The id of the section that owns a path: `/` is the dashboard, anything else matches by prefix. */
export function activeSection(pathname: string): string {
  const items = navigation.flatMap((group) => group.items);
  const match = items.find((item) => item.to !== '/' && (pathname === item.to || pathname.startsWith(`${item.to}/`)));
  return match?.id ?? 'dashboard';
}
