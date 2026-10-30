import { createContext, createElement, useContext, useMemo, useState, type ReactElement, type ReactNode } from 'react';

import type { Session } from '../../api/generated/admin.schemas';

// The signed-in session (access token + AdminUser), held in React state only: never in
// localStorage, sessionStorage or a JS-readable cookie (FR-034). A reload signs the editor out
// until D2 restores the session from the HttpOnly refresh cookie (POST /admin/api/auth/refresh).

interface SessionValue {
  session: Session | null;
  signIn: (session: Session) => void;
  signOut: () => void;
}

const SessionContext = createContext<SessionValue | null>(null);

export function SessionProvider({ children }: { children: ReactNode }): ReactElement {
  const [session, setSession] = useState<Session | null>(null);
  const value = useMemo<SessionValue>(
    () => ({
      session,
      signIn: setSession,
      // D1: the logout route answers 501, so signing out only drops the in-memory session. D2 calls it.
      signOut: () => setSession(null),
    }),
    [session],
  );
  return createElement(SessionContext.Provider, { value }, children);
}

export function useSession(): SessionValue {
  const value = useContext(SessionContext);
  if (!value) {
    throw new Error('useSession must be used inside <SessionProvider>');
  }
  return value;
}
