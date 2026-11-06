-- One-time repair, written 2026-11-06. Runbook: docs/runbooks/live-poller.md, "Repairing a lost result".
--
-- 17 of the 18 matches that kicked off at 22:00 Cairo on 2026-11-05 lost their result at 00:05: YallaKora's list
-- moved to the new day during the 10-minute wait for a lone full time, so the watchdog sent them to the clock.
--
-- The scores are the finished rows on https://www.yallakora.com/matches-center?date=2026-11-05. They equal
-- match_live_state on 16 rows. On 853 that memory says 1-0, from a row YallaKora later corrected; the page and
-- FilGoal's match page (378209) both say 2-0.
--
-- It stops without writing unless all 17 are still as the poller left them, so a second run changes nothing.

BEGIN;

CREATE TEMP TABLE repair_results (
    match_id bigint PRIMARY KEY,
    home smallint NOT NULL,
    away smallint NOT NULL
) ON COMMIT DROP;

INSERT INTO repair_results (match_id, home, away) VALUES
    (834, 1, 2),  -- ألكمار x يوفنتوس
    (836, 2, 3),  -- شتورم غراتس x سيليي
    (837, 0, 2),  -- سندرلاند x دينامو زغرب
    (838, 1, 2),  -- سيلتا فيغو x سان جيلواز
    (839, 3, 2),  -- تورينسي x آرارات أرمينيا
    (840, 0, 2),  -- بئر السبع x أوفي كريت
    (841, 0, 1),  -- باير ليفركوزن x مارسيليا
    (842, 3, 1),  -- بنفيكا x ليخ بوزنان
    (852, 1, 1),  -- ريغا x يابلونك
    (853, 2, 0),  -- موناكو x نوردشيلاند
    (854, 2, 1),  -- كوبنهاغن x إيبيريا
    (855, 2, 1),  -- باناثينايكوس x سسكا صوفيا
    (856, 3, 0),  -- لوجانو x زالجيريس
    (857, 0, 1),  -- خيتافي x برايتون
    (858, 3, 1),  -- تفينتي أنشخيده x بافوس
    (859, 1, 1),  -- سينت ترويدن x بران
    (860, 2, 0);  -- كرايوفا x إيجناتيا

DO $$
DECLARE
    ready integer;
BEGIN
    SELECT count(*) INTO ready
    FROM matches m
    JOIN repair_results r ON r.match_id = m.id
    WHERE m.status_source = 'clock'
      AND m.status = 'scheduled'
      AND m.home_score IS NULL
      AND m.kickoff_at = timestamptz '2026-11-05 20:00+00'
      AND NOT m.locked_fields && ARRAY['status', 'home_score', 'away_score', 'home_pen', 'away_pen'];
    IF ready <> 17 THEN
        RAISE EXCEPTION 'expected 17 matches still on the clock, found %: nothing was written', ready;
    END IF;
END $$;

UPDATE matches m
SET status = 'finished',
    status_source = 'feed',
    status_label = 'انتهت',
    period = NULL,
    minute = NULL,
    home_score = r.home,
    away_score = r.away,
    status_updated_at = now(),
    updated_at = now()
FROM repair_results r
WHERE m.id = r.match_id;

UPDATE match_live_state l
SET confirmed_home = r.home,
    confirmed_away = r.away,
    updated_at = now()
FROM repair_results r
WHERE l.match_id = r.match_id
  AND (l.confirmed_home IS DISTINCT FROM r.home OR l.confirmed_away IS DISTINCT FROM r.away);

-- Last, as in the app: an ETag built from these versions must change after the rows do.
UPDATE dataset_versions SET version = version + 1, updated_at = now() WHERE name IN ('matches', 'live');

SELECT m.id, m.home_team_name, m.away_team_name, m.status, m.status_source, m.home_score, m.away_score
FROM matches m
JOIN repair_results r ON r.match_id = m.id
ORDER BY m.id;

COMMIT;
