import { describe, expect, it, vi } from 'vitest';

import {
  cairoDay,
  cairoDayBounds,
  cairoWallTimeToUtc,
  formatCairoClock,
  formatCairoDayLabel,
  formatCairoTime,
  shiftCairoDay,
  utcToCairoWallTime,
} from './cairoTime';

// Egypt's 2026 daylight-saving change: +03:00 from Friday 24 April to Thursday 29 October, +02:00
// either side of it. The module never reads the machine's zone, so these assertions hold under any
// TZ (CI runs the suite under TZ=UTC and TZ=Asia/Riyadh).
describe('cairoTime', () => {
  describe('a Cairo wall time to a UTC instant', () => {
    it('stores 12:00 Cairo as 09:00Z while DST is on (April)', () => {
      expect(cairoWallTimeToUtc('2026-04-25T12:00')).toBe('2026-04-25T09:00:00.000Z');
    });

    it('stores 12:00 Cairo as 10:00Z once DST is off (November)', () => {
      expect(cairoWallTimeToUtc('2026-11-15T12:00')).toBe('2026-11-15T10:00:00.000Z');
    });

    it('stores a kickoff either side of the October change with the right offset', () => {
      expect(cairoWallTimeToUtc('2026-10-29T20:00')).toBe('2026-10-29T17:00:00.000Z');
      expect(cairoWallTimeToUtc('2026-10-30T20:00')).toBe('2026-10-30T18:00:00.000Z');
    });

    it('round-trips a wall time through UTC', () => {
      expect(utcToCairoWallTime(cairoWallTimeToUtc('2026-07-04T21:30'))).toBe('2026-07-04T21:30');
    });
  });

  describe('formatting', () => {
    it('shows Cairo time with Western digits', () => {
      expect(formatCairoTime('2026-10-31T18:00:00Z')).toBe('20:00');
      expect(formatCairoTime('2026-06-15T21:05:00Z')).toBe('00:05');
    });

    it('reads a clock for the table with its Arabic period', () => {
      expect(formatCairoClock('2026-10-31T18:05:00Z')).toEqual({ time: '8:05', period: 'م' });
      expect(formatCairoClock('2026-10-31T06:05:00Z')).toEqual({ time: '8:05', period: 'ص' });
    });

    it('labels a day tab in Arabic', () => {
      expect(formatCairoDayLabel('2026-10-31')).toBe('31 أكتوبر');
      expect(shiftCairoDay('2026-10-31', 1)).toBe('2026-11-01');
      expect(shiftCairoDay('2026-10-31', -1)).toBe('2026-10-30');
    });

    it('gives the Cairo calendar day of a UTC instant', () => {
      // 22:30Z on the 30th is already the 31st in Cairo.
      expect(cairoDay('2026-10-30T22:30:00Z')).toBe('2026-10-31');
      expect(cairoDay('2026-10-30T20:30:00Z')).toBe('2026-10-30');
    });

    it('ignores the machine time zone', () => {
      const seen: string[] = [];
      for (const zone of ['UTC', 'Asia/Riyadh', 'America/New_York']) {
        vi.stubEnv('TZ', zone);
        seen.push(`${formatCairoTime('2026-06-15T12:00:00Z')} ${cairoDay('2026-06-15T22:30:00Z')}`);
      }
      vi.unstubAllEnvs();

      expect(seen).toEqual(['15:00 2026-06-16', '15:00 2026-06-16', '15:00 2026-06-16']);
    });
  });

  describe('day bounds', () => {
    it('covers exactly one Cairo day in UTC', () => {
      expect(cairoDayBounds('2026-10-31')).toEqual({
        from: '2026-10-30T22:00:00.000Z',
        to: '2026-10-31T22:00:00.000Z',
      });
    });

    it('moves with the offset while DST is on', () => {
      expect(cairoDayBounds('2026-06-15')).toEqual({
        from: '2026-06-14T21:00:00.000Z',
        to: '2026-06-15T21:00:00.000Z',
      });
    });

    it('covers the 24-hour Cairo day that holds neither of two DST days', () => {
      // 29 October 2026 is 25 hours long in Cairo (the clocks go back at 24:00).
      const bounds = cairoDayBounds('2026-10-29');
      expect(bounds.from).toBe('2026-10-28T21:00:00.000Z');
      expect(bounds.to).toBe('2026-10-29T22:00:00.000Z');
    });
  });
});
