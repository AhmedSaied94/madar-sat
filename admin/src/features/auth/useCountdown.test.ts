import { act, renderHook } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { formatCountdown, useCountdown } from './useCountdown';

describe('formatCountdown', () => {
  it.each([
    [872, '14:32'],
    [60, '01:00'],
    [9, '00:09'],
    [0, '00:00'],
  ])('%i s reads %s in Western digits', (seconds, text) => {
    expect(formatCountdown(seconds)).toBe(text);
  });
});

describe('useCountdown', () => {
  it('counts the seconds left until a moment, then stops at zero', () => {
    vi.useFakeTimers();
    const until = Date.now() + 2000;
    const { result } = renderHook(() => useCountdown(until));

    expect(result.current).toBe(2);
    act(() => vi.advanceTimersByTime(1000));
    expect(result.current).toBe(1);
    act(() => vi.advanceTimersByTime(5000));
    expect(result.current).toBe(0);
  });

  it('is zero without a moment', () => {
    const { result } = renderHook(() => useCountdown(null));

    expect(result.current).toBe(0);
  });
});
