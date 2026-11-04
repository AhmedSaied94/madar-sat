import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useState, type ReactElement } from 'react';
import { createBrowserRouter, Navigate, RouterProvider, useLocation, type RouteObject } from 'react-router-dom';

import { EmptyState } from '../components/EmptyState/EmptyState';
import { ToastProvider } from '../components/Toast/Toast';
import { LoginPage } from '../features/auth/LoginPage';
import { SessionProvider, useSession } from '../features/auth/session';
import { ChannelsPage } from '../features/channels/ChannelsPage';
import { CommentatorsPage } from '../features/commentators/CommentatorsPage';
import { CompetitionsPage } from '../features/competitions/CompetitionsPage';
import { DashboardPage } from '../features/dashboard/DashboardPage';
import { MatchEditor } from '../features/matches/MatchEditor';
import { MatchesPage } from '../features/matches/MatchesPage';
import { SatellitesPage } from '../features/satellites/SatellitesPage';
import { SourceRunPage } from '../features/sources/SourceRunPage';
import { SourcesPage } from '../features/sources/SourcesPage';
import { RightsHoldersPage } from '../features/rights/RightsHoldersPage';
import { TeamsPage } from '../features/teams/TeamsPage';
import { Shell } from '../features/shell/Shell';
import { shell } from '../i18n/ar';

/** The A0 shell for a signed-in editor; anyone else goes to /login and comes back afterwards. */
function SignedInShell(): ReactElement {
  const { session, restoring, signOut } = useSession();
  const location = useLocation();

  // On a reload the access token is gone (it lives in memory only); wait for the refresh cookie to
  // restore it before deciding the editor is signed out.
  if (!session && restoring) {
    return (
      <p role="status" aria-live="polite" className="p-8 text-center text-text-secondary">
        {shell.restoring}
      </p>
    );
  }
  if (!session) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }
  return <Shell user={session.admin} onLogout={signOut} />;
}

/** Sections that arrive on a later day show the same placeholder inside the shell. */
function ComingSoon(): ReactElement {
  return <EmptyState kind="empty" title={shell.comingSoonTitle} body={shell.comingSoonBody} />;
}

// A data router (`createBrowserRouter`) rather than `<BrowserRouter>`: A4's unsaved-changes guard
// needs `useBlocker`, which only exists in a data router (research R24).
export const appRoutes: RouteObject[] = [
  { path: '/login', element: <LoginPage /> },
  {
    element: <SignedInShell />,
    children: [
      // A2 is the landing page after login (T104).
      { index: true, element: <DashboardPage /> },
      { path: 'matches', element: <MatchesPage /> },
      { path: 'matches/new', element: <MatchEditor /> },
      { path: 'matches/:id', element: <MatchEditor /> },
      { path: 'teams', element: <TeamsPage /> },
      { path: 'competitions', element: <CompetitionsPage /> },
      { path: 'channels', element: <ChannelsPage /> },
      { path: 'satellites', element: <SatellitesPage /> },
      { path: 'rights-holders', element: <RightsHoldersPage /> },
      { path: 'commentators', element: <CommentatorsPage /> },
      { path: 'sources', element: <SourcesPage /> },
      { path: 'import-runs/:id', element: <SourceRunPage /> },
      { path: '*', element: <ComingSoon /> },
    ],
  },
];

export function App(): ReactElement {
  const [queryClient] = useState(
    () => new QueryClient({ defaultOptions: { queries: { retry: 1, refetchOnWindowFocus: false } } }),
  );
  const [router] = useState(() => createBrowserRouter(appRoutes));

  return (
    <QueryClientProvider client={queryClient}>
      <SessionProvider>
        <ToastProvider>
          <RouterProvider router={router} />
        </ToastProvider>
      </SessionProvider>
    </QueryClientProvider>
  );
}
