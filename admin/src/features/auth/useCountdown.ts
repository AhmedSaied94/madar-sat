import { useEffect, useState } from 'react';

const secondsUntil = (until: number | null): number => (until === null ? 0 : Math.max(0, Math.ceil((until - Date.now()) / 1000)));

/** Whole seconds left until `until` (epoch ms), ticking once a second and stopping at zero. */
export function useCountdown(until: number | null): number {
  const [remaining, setRemaining] = useState(() => secondsUntil(until));

  useEffect(() => {
    setRemaining(secondsUntil(until));
    if (until === null) return undefined;

    const timer = setInterval(() => {
      const left = secondsUntil(until);
      setRemaining(left);
      if (left === 0) clearInterval(timer);
    }, 1000);
    return () => clearInterval(timer);
  }, [until]);

  return remaining;
}

/** mm:ss with Western digits, built by hand so no locale can swap the digits (constitution III). */
export function formatCountdown(totalSeconds: number): string {
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}
