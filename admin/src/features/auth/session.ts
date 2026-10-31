import {
  createContext,
  createElement,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactElement,
  type ReactNode,
} from 'react';

import type { Session } from '../../api/generated/admin.schemas';
import { bindSession, endSession, refreshSession, setAccessToken } from '../../api/http';

// The signed-in session (access token + AdminUser), held in React state only: the token is never in
// localStorage, sessionStorage or a JS-readable cookie (FR-034), it lives in the mutator's memory.
// On load the provider restores the session from the HttpOnly refresh cookie, and it refreshes again
// at `expires_in − 60 s`, so a working editor is never signed out mid-task (research R24).

interface SessionValue {
  session: Session | null;
  signIn: (session: Session) => void;
  signOut: () => void;
}

const SessionContext = createContext<SessionValue | null>(null);

/** Refresh this many seconds before the token expires. */
export const REFRESH_LEAD_S = 60;

export function SessionProvider({ children }: { children: ReactNode }): ReactElement {
  const [session, setSession] = useState<Session | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // One restore on mount; a refresh done inside the mutator (after a 401) lands here too.
  useEffect(() => {
    let cancelled = false;
    bindSession({
      onRefreshed: (fresh) => {
        if (!cancelled) setSession(fresh);
      },
      onExpired: () => {
        if (!cancelled) setSession(null);
      },
    });

    refreshSession()
      .then((restored) => {
        if (!cancelled) setSession(restored);
      })
      .catch(() => undefined);

    return () => {
      cancelled = true;
      bindSession({});
    };
  }, []);

  const signIn = useCallback((next: Session) => {
    setAccessToken(next.access_token);
    setSession(next);
  }, []);

  const signOut = useCallback(() => {
    setSession(null);
    void endSession();
  }, []);

  // Refresh a minute before the access token expires, and again for each new one.
  useEffect(() => {
    if (timer.current) clearTimeout(timer.current);
    if (!session) return;
    timer.current = setTimeout(
      () => {
        // A refresh that fails on the network keeps the session (and A4's unsaved work) mounted; only a
        // definitive refusal ends it, through `bindSession`'s `onExpired` (A-R1-19).
        refreshSession()
          .then(setSession)
          .catch(() => undefined);
      },
      Math.max(session.expires_in - REFRESH_LEAD_S, 0) * 1000,
    );
    return () => {
      if (timer.current) clearTimeout(timer.current);
    };
  }, [session]);

  const value = useMemo<SessionValue>(() => ({ session, signIn, signOut }), [session, signIn, signOut]);
  return createElement(SessionContext.Provider, { value }, children);
}

export function useSession(): SessionValue {
  const value = useContext(SessionContext);
  if (!value) {
    throw new Error('useSession must be used inside <SessionProvider>');
  }
  return value;
}
