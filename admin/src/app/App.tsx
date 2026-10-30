import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useState, type ReactElement } from 'react';
import { BrowserRouter, Navigate, Route, Routes, useLocation } from 'react-router-dom';

import { EmptyState } from '../components/EmptyState/EmptyState';
import { ToastProvider } from '../components/Toast/Toast';
import { LoginPage } from '../features/auth/LoginPage';
import { SessionProvider, useSession } from '../features/auth/session';
import { Shell } from '../features/shell/Shell';
import { shell } from '../i18n/ar';

/** The A0 shell for a signed-in editor; anyone else goes to /login and comes back afterwards. */
function SignedInShell(): ReactElement {
  const { session, signOut } = useSession();
  const location = useLocation();

  if (!session) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }
  return <Shell user={session.admin} onLogout={signOut} />;
}

/** D1 has no admin screens yet: every section shows the same placeholder inside the shell. */
function ComingSoon(): ReactElement {
  return <EmptyState kind="empty" title={shell.comingSoonTitle} body={shell.comingSoonBody} />;
}

export function AppRoutes(): ReactElement {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<SignedInShell />}>
        <Route index element={<ComingSoon />} />
        <Route path="*" element={<ComingSoon />} />
      </Route>
    </Routes>
  );
}

export function App(): ReactElement {
  const [queryClient] = useState(
    () => new QueryClient({ defaultOptions: { queries: { retry: 1, refetchOnWindowFocus: false } } }),
  );

  return (
    <QueryClientProvider client={queryClient}>
      <SessionProvider>
        <ToastProvider>
          <BrowserRouter>
            <AppRoutes />
          </BrowserRouter>
        </ToastProvider>
      </SessionProvider>
    </QueryClientProvider>
  );
}
