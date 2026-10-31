import { formatInTimeZone, fromZonedTime } from 'date-fns-tz';

// The admin works in Cairo time and stores UTC instants (research R24, FR-030): a kickoff the editor
// types on the A4 form is a Cairo wall time, the API takes the UTC instant, and A3 shows it back in
// Cairo. Everything here passes an explicit zone and a latn numbering system, so neither the
// machine's TZ nor the browser's locale can shift a time or turn its digits Arabic-Indic.
export const ADMIN_TIME_ZONE = 'Africa/Cairo';

/** Numbering system forced on every number the admin formats (constitution III: Western digits). */
export const LATN_DIGITS = 'ar-EG-u-nu-latn';

const WALL_TIME = "yyyy-MM-dd'T'HH:mm";

const timeFormat = new Intl.DateTimeFormat(LATN_DIGITS, {
  timeZone: ADMIN_TIME_ZONE,
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
});

/** A UTC instant (ISO-8601) from the Cairo wall time a `datetime-local` holds (`YYYY-MM-DDTHH:mm`). */
export function cairoWallTimeToUtc(wallTime: string): string {
  return fromZonedTime(wallTime, ADMIN_TIME_ZONE).toISOString();
}

/** The `YYYY-MM-DDTHH:mm` a `datetime-local` shows for a UTC instant, in Cairo time. */
export function utcToCairoWallTime(instant: string): string {
  return formatInTimeZone(instant, ADMIN_TIME_ZONE, WALL_TIME);
}

/** `HH:mm` in Cairo, Western digits. */
export function formatCairoTime(instant: string): string {
  return timeFormat.format(new Date(instant));
}

const utcTimeFormat = new Intl.DateTimeFormat(LATN_DIGITS, {
  timeZone: 'UTC',
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
});

/** `HH:mm` UTC, Western digits: the hint under A4's Cairo time field says what is stored (A-R1-12). */
export function formatUtcTime(instant: string): string {
  return utcTimeFormat.format(new Date(instant));
}

const clockFormat = new Intl.DateTimeFormat(LATN_DIGITS, {
  timeZone: ADMIN_TIME_ZONE,
  hour: 'numeric',
  minute: '2-digit',
  hour12: true,
});

/** The A3 table's clock: `{ time: '9:05', period: 'م' }`, as the board draws it. */
export function formatCairoClock(instant: string): { time: string; period: string } {
  const parts = clockFormat.formatToParts(new Date(instant));
  const value = (type: Intl.DateTimeFormatPartTypes): string => parts.find((part) => part.type === type)?.value ?? '';
  return { time: `${value('hour')}:${value('minute')}`, period: value('dayPeriod') };
}

const dayFormat = new Intl.DateTimeFormat(LATN_DIGITS, {
  timeZone: ADMIN_TIME_ZONE,
  day: 'numeric',
  month: 'long',
});

/** «31 أكتوبر»: a day tab's label (the day itself is a Cairo calendar day). */
export function formatCairoDayLabel(day: string): string {
  return dayFormat.format(fromZonedTime(`${day}T12:00`, ADMIN_TIME_ZONE));
}

/** The day `offset` days from `day`, on the calendar (A3's أمس / غداً tabs). */
export function shiftCairoDay(day: string, offset: number): string {
  return new Date(Date.parse(`${day}T00:00:00Z`) + offset * 86_400_000).toISOString().slice(0, 10);
}

/** The Cairo calendar day (`YYYY-MM-DD`) a UTC instant falls on, for A3's tabs and grouping. */
export function cairoDay(instant: string): string {
  return formatInTimeZone(instant, ADMIN_TIME_ZONE, 'yyyy-MM-dd');
}

/** The UTC `from`/`to` that cover exactly one Cairo calendar day (A3 asks the API for this range). */
export function cairoDayBounds(day: string): { from: string; to: string } {
  const nextDay = new Date(Date.parse(`${day}T00:00:00Z`) + 86_400_000).toISOString().slice(0, 10);
  return {
    from: fromZonedTime(`${day}T00:00`, ADMIN_TIME_ZONE).toISOString(),
    to: fromZonedTime(`${nextDay}T00:00`, ADMIN_TIME_ZONE).toISOString(),
  };
}
