-- Madar Sat: PostgreSQL 16 base schema, replacing Firestore + the published hosting JSON.
-- It becomes Alembic revision 0001 unchanged (system-design §6.2.1). Designed from the snapshot in
-- migration/data/; migration/README.md has the ETL rules and data-quality notes.
-- The 2026-10-28 version, a straight copy of the Firestore shape, is in migration/archive/.
--
-- Conventions
--   * bigint identity PKs. legacy_id keeps the Firestore document id so the ETL can resolve references.
--   * Empty strings and placeholders in the source ('', '⚽', 'غير مدرج') become NULL.
--   * "from:" comments name the source field, for the ETL.
--   * Settings lists that only ordered or flagged rows (satPriority, compPriority, channelOrder,
--     rightsOrder) are folded into columns on the rows themselves.
--   * Media (logos, photos, voice clips) is referenced by media_assets id, never by URL. The API builds
--     absolute URLs from media_base_url, so moving the media host is a config change.
--   * Card-sharing labels and BISS keys are not stored (constitution, O3). Access is free | encrypted,
--     plus the official provider or package.
--   * Importers upsert through the *_external_ids tables, keyed by (source, external_id).
--   * updated_at is maintained by the set_updated_at trigger and moves only on a real change.
--   * Names: CHECK constraints are named ck_<table>_<rule>. Every other constraint keeps PostgreSQL's
--     default name (<table>_pkey, <table>_<columns>_key, <table>_<columns>_fkey), so later revisions can
--     drop them by name. The SQLAlchemy naming_convention must produce the same names.
--   * No transaction control here: Alembic owns the transaction. Run the file as one script through a
--     driver that accepts several statements per call (psycopg's exec_driver_sql); asyncpg's prepared
--     statements reject that.
--   * ar_normalize relies on lower(), so the database needs a UTF-8 libc locale (the postgres image
--     default, en_US.utf8), not "C".

-- ─── Types and functions ────────────────────────────────────────────────────

CREATE DOMAIN polarization AS char(1) CHECK (VALUE IN ('H', 'V', 'L', 'R'));
CREATE DOMAIN frequency_mhz AS integer CHECK (VALUE BETWEEN 2000 AND 13000);  -- snapshot: 10719–12853
CREATE DOMAIN symbol_rate AS integer CHECK (VALUE BETWEEN 500 AND 60000);     -- ksym/s; snapshot: 1667–45000
CREATE DOMAIN sport AS text CHECK (VALUE IN ('football', 'basketball', 'handball', 'volleyball', 'tennis'));

-- Arabic-insensitive matching key (system-design §6.2.4), the same rules as the old app's normalizeArabic
-- (old_app/src/utils/arabicMatch.js): lowercase, strip tashkeel and tatweel, أ/إ/آ/ٱ → ا, ة → ه,
-- ى/ئ → ي, ؤ → و, punctuation and symbols → space, collapse spaces. The character sets are spelled out
-- instead of using [[:alnum:]], whose meaning outside ASCII depends on the database locale.
CREATE FUNCTION ar_normalize(value text) RETURNS text
  LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
  RETURN btrim(regexp_replace(
    regexp_replace(
      translate(
        regexp_replace(lower(value), '[ً-ْٰـ]', '', 'g'),
        'أإآٱةىئؤ', 'ااااهييو'),
      '[!-/:-@[-`{-~ -¿×÷،؛؟٪-٭۔ -⁯←-⯿\U0001F000-\U0001FAFF]',
      ' ', 'g'),
    '[ \t\r\n]+', ' ', 'g'));

-- Sets updated_at on UPDATE, but only when something else changed: importers re-upsert unchanged rows
-- on every run, and /v1/channels/sync must not resend them. name_norm is excluded because BEFORE
-- triggers can't read generated columns, and it follows name anyway.
CREATE FUNCTION set_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF (to_jsonb(NEW) - 'updated_at' - 'name_norm') IS DISTINCT FROM (to_jsonb(OLD) - 'updated_at' - 'name_norm') THEN
    NEW.updated_at := now();
  ELSE
    NEW.updated_at := OLD.updated_at;
  END IF;
  RETURN NEW;
END
$$;

-- For tables whose rows are history and are never deleted (system-design §6.2.5).
CREATE FUNCTION forbid_delete() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION '% rows are never deleted', TG_TABLE_NAME USING ERRCODE = 'restrict_violation';
END
$$;

-- ─── Sources and media ──────────────────────────────────────────────────────

-- Where data comes from. Provenance columns, external ids and import runs reference it, so a new
-- adapter is one INSERT instead of a change to every CHECK.
CREATE TABLE sources (
  name         text PRIMARY KEY CONSTRAINT ck_sources_name CHECK (name ~ '^[a-z][a-z0-9_]*$'),
  kind         text NOT NULL CONSTRAINT ck_sources_kind CHECK (kind IN ('scraper', 'api', 'internal')),
  is_enabled   boolean NOT NULL DEFAULT true,   -- admin pause / resume (A13)
  paused_until timestamptz,                     -- set by the circuit breaker
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);
INSERT INTO sources (name, kind) VALUES
  ('ysscores', 'scraper'),
  ('livesoccertv', 'scraper'),
  ('sporteventz', 'scraper'),
  ('yallakora', 'scraper'),
  ('api_football', 'api'),
  ('manual', 'internal'),    -- written by an admin
  ('legacy', 'internal');    -- loaded from the Sat Air snapshot, original source unknown

-- Content-addressed media (system-design §6.9), stored at /srv/media/<path>.
CREATE TABLE media_assets (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  sha256       char(64) NOT NULL UNIQUE CONSTRAINT ck_media_assets_sha256 CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  kind         text NOT NULL CONSTRAINT ck_media_assets_kind CHECK (kind IN ('logo', 'photo', 'audio')),
  path         text NOT NULL UNIQUE,            -- "logo/9f/9f…e1.webp", relative to the media root
  mime         text NOT NULL CONSTRAINT ck_media_assets_mime CHECK (mime IN ('image/webp', 'audio/mp4')),
  bytes        integer NOT NULL CONSTRAINT ck_media_assets_bytes CHECK (bytes BETWEEN 1 AND 2097152),
  width        smallint,
  height       smallint,
  duration_ms  integer,
  original_url text,                            -- where it was rehosted from; kept for takedown requests
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_media_assets_image CHECK (
    (mime = 'image/webp') = (width IS NOT NULL AND height IS NOT NULL)
    AND width BETWEEN 1 AND 512 AND height BETWEEN 1 AND 512),
  CONSTRAINT ck_media_assets_audio CHECK (
    (mime = 'audio/mp4') = (duration_ms IS NOT NULL) AND duration_ms BETWEEN 1 AND 30000)
);
CREATE INDEX media_assets_original_url_idx ON media_assets (original_url);

-- ─── Reference data ─────────────────────────────────────────────────────────

-- Satellites, plus one terrestrial pseudo-satellite ("DVB T2") that DVB-T2 multiplexes hang off.
CREATE TABLE satellites (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  legacy_id          text UNIQUE,
  slug               text NOT NULL UNIQUE CONSTRAINT ck_satellites_slug CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
                                                -- join key for importers ("nilesat-7-0w", "eutel-16-0e-africa")
  kind               text NOT NULL DEFAULT 'satellite' CONSTRAINT ck_satellites_kind CHECK (kind IN ('satellite', 'terrestrial')),
  name_en            text NOT NULL,             -- from: en, trimmed ("Nilesat 7.0W")
  name_ar            text NOT NULL,             -- from: ar
  orbital_position   numeric(4,1),              -- degrees, east positive (-7.0 = 7.0°W); parsed from name_en
  logo_asset_id      bigint REFERENCES media_assets (id),   -- from: logo (empty in all rows today)
  best_frequency_mhz frequency_mhz,             -- from: bestFreq ("11996 V 27500"), split like channels
  best_polarization  polarization,
  best_symbol_rate   symbol_rate,
  worst_frequency_mhz frequency_mhz,            -- from: worstFreq
  worst_polarization polarization,
  worst_symbol_rate  symbol_rate,
  reception_url      text,                      -- from: receptionUrl (YouTube how-to video)
  priority           integer,                   -- from: settings/satPriority index; lower is shown first
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_satellites_orbital_position CHECK (
    (kind = 'satellite') = (orbital_position IS NOT NULL) AND orbital_position BETWEEN -180 AND 180),
  CONSTRAINT ck_satellites_best_tuning CHECK (
    (best_frequency_mhz IS NULL) = (best_polarization IS NULL) AND (best_frequency_mhz IS NULL) = (best_symbol_rate IS NULL)),
  CONSTRAINT ck_satellites_worst_tuning CHECK (
    (worst_frequency_mhz IS NULL) = (worst_polarization IS NULL) AND (worst_frequency_mhz IS NULL) = (worst_symbol_rate IS NULL))
);
CREATE UNIQUE INDEX satellites_name_en_key ON satellites (lower(btrim(name_en)));

CREATE TABLE competitions (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  legacy_id     text UNIQUE,
  sport         sport NOT NULL DEFAULT 'football',
  name          text NOT NULL,                  -- from: name; the old data references competitions by name
  name_norm     text NOT NULL GENERATED ALWAYS AS (ar_normalize(name)) STORED,
  logo_asset_id bigint REFERENCES media_assets (id),   -- from: logo
  priority      integer,                        -- from: settings/compPriority index (51 of 134 ranked)
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX competitions_sport_name_norm_key ON competitions (sport, name_norm);

-- A competition's id at each source (none in the snapshot).
CREATE TABLE competition_external_ids (
  source         text NOT NULL REFERENCES sources (name),
  external_id    text NOT NULL,
  competition_id bigint NOT NULL REFERENCES competitions (id) ON DELETE CASCADE,
  PRIMARY KEY (source, external_id)
);
CREATE INDEX competition_external_ids_competition_id_idx ON competition_external_ids (competition_id);

-- One row per channel carriage or broadcaster entry, as in Firestore: the same channel name appears on
-- several rows. kind says which, and ck_channels_kind_fields says which columns each kind uses:
--   satellite    a carriage on a satellite: satellite_id, plus the tuning or a frequency_note
--   terrestrial  a DVB-T2 multiplex on the "DVB T2" satellites row: frequency_note ("UHF 32")
--   platform     a broadcaster or streaming service in a country, no satellite. LiveSoccerTV and
--                ysscores create these (1,469 in the snapshot); MatchDetail lists them as "platforms".
CREATE TABLE channels (
  id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  legacy_id      text UNIQUE,                   -- matchDays.channelIds point at this
  kind           text NOT NULL CONSTRAINT ck_channels_kind CHECK (kind IN ('satellite', 'terrestrial', 'platform')),
  name           text NOT NULL,
  name_norm      text NOT NULL GENERATED ALWAYS AS (ar_normalize(name)) STORED,
  display_name   text,                          -- from: displayName
  logo_asset_id  bigint REFERENCES media_assets (id),   -- from: logo
  category       text CONSTRAINT ck_channels_category CHECK (category IN ('sports', 'entertainment')),
  country        text,                          -- Arabic country name (platform rows)
  satellite_id   bigint REFERENCES satellites (id),   -- from: satelliteEn; satellite (Arabic) is derived, not stored
  frequency_mhz  frequency_mhz,                 -- from: frequency "11366 V 30000", split into three columns
  polarization   polarization,
  symbol_rate    symbol_rate,
  frequency_note text,                          -- from: frequency when it is not DVB-S ("UHF 32")
  access         text CONSTRAINT ck_channels_access CHECK (access IN ('free', 'encrypted')),   -- from: free
  provider       text,                          -- official provider ("beIN"); never a card-sharing label
  package        text,                          -- official package name
  beam           text CONSTRAINT ck_channels_beam CHECK (beam IN ('wide', 'narrow')),
                                                -- from: bundle «الحزمة»: عامة → wide, ضيقة → narrow
  show_in_match  boolean NOT NULL DEFAULT false,   -- from: showInMatch; match pages list only Nilesat/Badr channels unless true
  sort_order     integer,                       -- from: settings/channelOrder index
  deleted_at     timestamptz,                   -- soft delete: /v1/channels/sync reports these ids as deleted
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_channels_tuning CHECK (
    (frequency_mhz IS NULL) = (polarization IS NULL) AND (frequency_mhz IS NULL) = (symbol_rate IS NULL)),
  CONSTRAINT ck_channels_kind_fields CHECK (CASE kind
    WHEN 'satellite'   THEN satellite_id IS NOT NULL AND access IS NOT NULL
    WHEN 'terrestrial' THEN satellite_id IS NOT NULL AND access IS NOT NULL AND frequency_mhz IS NULL
    ELSE satellite_id IS NULL AND frequency_mhz IS NULL AND frequency_note IS NULL AND beam IS NULL
  END)
);
CREATE INDEX channels_satellite_id_idx ON channels (satellite_id, sort_order) WHERE deleted_at IS NULL;
CREATE INDEX channels_name_norm_idx ON channels (name_norm);
CREATE INDEX channels_updated_at_idx ON channels (updated_at, id);   -- /v1/channels/sync cursor
CREATE UNIQUE INDEX channels_carriage_key ON channels (name_norm, satellite_id, frequency_mhz, polarization, symbol_rate)
  WHERE kind = 'satellite' AND frequency_mhz IS NOT NULL AND deleted_at IS NULL;
CREATE UNIQUE INDEX channels_platform_key ON channels (name_norm, country) NULLS NOT DISTINCT
  WHERE kind = 'platform' AND deleted_at IS NULL;

-- Channel names hidden from match pages wherever they appear (matched against the normalized name and
-- display_name), so newly imported stubs with the same name are hidden too.
CREATE TABLE hidden_channel_names (
  name text PRIMARY KEY CONSTRAINT ck_hidden_channel_names_normalized CHECK (name = ar_normalize(name))
                                                -- from: settings/autoHiddenChannels.names
);

CREATE TABLE teams (
  id                     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  legacy_id              text UNIQUE,
  sport                  sport NOT NULL DEFAULT 'football',
  name                   text NOT NULL,         -- not unique: same name in different countries (الأهلي ×3)
  name_norm              text NOT NULL GENERATED ALWAYS AS (ar_normalize(name)) STORED,
  country                text,                  -- Arabic country name; tells same-named teams apart. Not in the snapshot
  logo_asset_id          bigint REFERENCES media_assets (id),
  stadium                text,
  primary_competition_id bigint REFERENCES competitions (id) ON DELETE SET NULL,  -- from: league (name)
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX teams_name_norm_idx ON teams (name_norm);
CREATE INDEX teams_primary_competition_id_idx ON teams (primary_competition_id);

-- A team's id at each source. from: ysId (ysscores team id)
CREATE TABLE team_external_ids (
  source      text NOT NULL REFERENCES sources (name),
  external_id text NOT NULL,
  team_id     bigint NOT NULL REFERENCES teams (id) ON DELETE CASCADE,
  PRIMARY KEY (source, external_id)
);
CREATE INDEX team_external_ids_team_id_idx ON team_external_ids (team_id);

CREATE TABLE team_competitions (              -- from: teams.leagues[] (names)
  team_id        bigint NOT NULL REFERENCES teams (id) ON DELETE CASCADE,
  competition_id bigint NOT NULL REFERENCES competitions (id) ON DELETE CASCADE,
  PRIMARY KEY (team_id, competition_id)
);
CREATE INDEX team_competitions_competition_id_idx ON team_competitions (competition_id);

-- Importer support: Arabic team name -> LiveSoccerTV team page. from: teamDict (doc id = Arabic name)
-- Neither side is unique: one page has several Arabic spellings, and one Arabic name (الأهلي) can mean
-- several clubs, told apart by team_id.
CREATE TABLE livesoccertv_teams (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  ar_name     text NOT NULL,                    -- from: ar (= doc id)
  ar_name_norm text NOT NULL GENERATED ALWAYS AS (ar_normalize(ar_name)) STORED,
  en_name     text NOT NULL,                    -- from: en
  country     text,                             -- LiveSoccerTV country slug; "countries" = national teams
  slug        text NOT NULL,                    -- livesoccertv.com/teams/<country>/<slug>/
  team_id     bigint REFERENCES teams (id) ON DELETE SET NULL,
  saved_at    timestamptz,                      -- from: savedAt
  CONSTRAINT livesoccertv_teams_ar_name_country_slug_key UNIQUE NULLS NOT DISTINCT (ar_name, country, slug)
);
CREATE INDEX livesoccertv_teams_ar_name_norm_idx ON livesoccertv_teams (ar_name_norm);
CREATE INDEX livesoccertv_teams_page_idx ON livesoccertv_teams (country, slug);
CREATE INDEX livesoccertv_teams_team_id_idx ON livesoccertv_teams (team_id);

-- from: settings/commentators.list, plus names that only appear inside matches
-- (their image/audio come from the copies on the match).
CREATE TABLE commentators (
  id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name           text NOT NULL,
  name_norm      text NOT NULL GENERATED ALWAYS AS (ar_normalize(name)) STORED,
  photo_asset_id bigint REFERENCES media_assets (id),   -- from: image
  audio_asset_id bigint REFERENCES media_assets (id),   -- from: audio (voice clip, ≤ 30 s)
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX commentators_name_norm_key ON commentators (name_norm);

-- Picker for free-text broadcasters on a match (e.g. "ON Sport 1"). from: settings/broadcasts.list
CREATE TABLE broadcast_presets (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name          text NOT NULL UNIQUE,
  logo_asset_id bigint REFERENCES media_assets (id)
);

-- ─── Broadcast rights ───────────────────────────────────────────────────────

-- A network that holds rights to competitions. from: rights
-- Its name is a brand ("CANAL+SPORT"), not a channels row: only 27 of 75 match a channel name.
CREATE TABLE rights_holders (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  legacy_id     text UNIQUE,
  name          text NOT NULL,                  -- from: channel
  logo_asset_id bigint REFERENCES media_assets (id),   -- from: channelLogo
  sort_order    integer,                        -- from: settings/rightsOrder index
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()   -- from: updatedAt
);

CREATE TABLE rights_holder_competitions (     -- from: rights.competitions[] (names)
  rights_holder_id bigint NOT NULL REFERENCES rights_holders (id) ON DELETE CASCADE,
  competition_id   bigint NOT NULL REFERENCES competitions (id) ON DELETE CASCADE,
  PRIMARY KEY (rights_holder_id, competition_id)
);
CREATE INDEX rights_holder_competitions_competition_id_idx ON rights_holder_competitions (competition_id);

-- How a rights holder is received. from: rights.frequencies[]
-- rights.satellite[] is not stored: it is the union of the carriages' satellites.
CREATE TABLE rights_holder_carriages (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  rights_holder_id bigint NOT NULL REFERENCES rights_holders (id) ON DELETE CASCADE,
  position         smallint NOT NULL,           -- array index
  access           text NOT NULL CONSTRAINT ck_rights_holder_carriages_access CHECK (access IN ('free', 'encrypted')),  -- from: free
  beam             text CONSTRAINT ck_rights_holder_carriages_beam CHECK (beam IN ('wide', 'narrow')),            -- from: bundle
  UNIQUE (rights_holder_id, position)
);

CREATE TABLE rights_holder_carriage_satellites (   -- from: frequencies[].satellite (string or array)
  carriage_id  bigint NOT NULL REFERENCES rights_holder_carriages (id) ON DELETE CASCADE,
  satellite_id bigint NOT NULL REFERENCES satellites (id),
  PRIMARY KEY (carriage_id, satellite_id)
);
CREATE INDEX rights_holder_carriage_satellites_satellite_id_idx ON rights_holder_carriage_satellites (satellite_id);

CREATE TABLE rights_holder_frequencies (      -- from: frequencies[].frequencies[]; frequencies[].frequency is the primary one
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  carriage_id   bigint NOT NULL REFERENCES rights_holder_carriages (id) ON DELETE CASCADE,
  frequency_mhz frequency_mhz NOT NULL,
  polarization  polarization NOT NULL,
  symbol_rate   symbol_rate NOT NULL,
  is_primary    boolean NOT NULL DEFAULT false,
  UNIQUE (carriage_id, frequency_mhz, polarization, symbol_rate)
);
CREATE UNIQUE INDEX rights_holder_frequencies_one_primary ON rights_holder_frequencies (carriage_id) WHERE is_primary;

-- ─── Matches ────────────────────────────────────────────────────────────────

-- from: matchDays/{YYYY-MM-DD}.matches[] (one Firestore doc per day holding an array).
-- Team and competition keep the displayed name next to the FK because the source links them
-- by name only: names can be ambiguous or missing from teams, and non-football events
-- (sporteventz) have competitions that are not in the competitions table yet.
-- Matches are history: they are never deleted (matches_forbid_delete).
CREATE TABLE matches (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  legacy_id          text UNIQUE,               -- from: id ("m_<ms>_<rand>")
  sport              sport NOT NULL DEFAULT 'football',   -- from: sport (sporteventz rows only)
  source             text NOT NULL REFERENCES sources (name),   -- who created the row; 'legacy' for the snapshot.
                                                --   Each source's id for the match is in match_external_ids
  match_date         date NOT NULL,             -- from: the matchDays doc id (listing day); ingestion only
  kickoff_at         timestamptz,               -- from: date + time ("10:00 م") read as Africa/Cairo wall clock,
                                                --   like the app does; NULL when time is "--:--"
  competition_id     bigint REFERENCES competitions (id) ON DELETE SET NULL,
  competition_name   text NOT NULL,             -- from: competition
  competition_stage  text,                      -- from: competitionStage
  home_team_id       bigint REFERENCES teams (id) ON DELETE SET NULL,
  home_team_name     text NOT NULL,             -- from: team1
  home_logo_asset_id bigint REFERENCES media_assets (id),   -- from: logo1 when it differs from the team's logo; NULL = use team logo
  away_team_id       bigint REFERENCES teams (id) ON DELETE SET NULL,
  away_team_name     text NOT NULL,             -- from: team2
  away_logo_asset_id bigint REFERENCES media_assets (id),   -- from: logo2
  stadium            text,
  commentator_id     bigint REFERENCES commentators (id) ON DELETE SET NULL,  -- from: commentator (+Image/Audio)
  is_live            boolean NOT NULL DEFAULT false,  -- from: live (manual override of the clock-based status)
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()   -- from: matchDays.updatedAt (per day in the source)
);
CREATE INDEX matches_match_date_idx ON matches (match_date);
CREATE INDEX matches_kickoff_at_idx ON matches (kickoff_at);
CREATE INDEX matches_competition_id_idx ON matches (competition_id, kickoff_at);
CREATE INDEX matches_home_team_id_idx ON matches (home_team_id, kickoff_at);
CREATE INDEX matches_away_team_id_idx ON matches (away_team_id, kickoff_at);
CREATE INDEX matches_commentator_id_idx ON matches (commentator_id) WHERE commentator_id IS NOT NULL;
CREATE TRIGGER matches_forbid_delete BEFORE DELETE ON matches FOR EACH ROW EXECUTE FUNCTION forbid_delete();

-- A match's id at each source. Importers upsert through it, and a cross-source merge moves the other
-- source's id onto the surviving row. from: ysMatchId, lstUrl, seId
CREATE TABLE match_external_ids (
  source      text NOT NULL REFERENCES sources (name),
  external_id text NOT NULL,                    -- LiveSoccerTV: the match page path
  match_id    bigint NOT NULL REFERENCES matches (id),
  url         text,                             -- the source's match page (from: lstUrl)
  PRIMARY KEY (source, external_id)
);
CREATE INDEX match_external_ids_match_id_idx ON match_external_ids (match_id);

-- from: matches[].channelIds (+ importedChannelIds, hiddenChannels, channelCommentators)
-- A channel referenced here can't be hard-deleted: soft-delete it or merge it into another channel,
-- so a match keeps the record of where it was shown.
CREATE TABLE match_channels (
  match_id        bigint NOT NULL REFERENCES matches (id),
  channel_id      bigint NOT NULL REFERENCES channels (id),
  -- Who added the link. An importer may only remove its own links (today's importedChannelIds).
  -- Other snapshot links can't be told apart (LVS.html and the admin both write channelIds), so they
  -- load as 'legacy'.
  source          text NOT NULL REFERENCES sources (name),
  is_hidden       boolean NOT NULL DEFAULT false,   -- from: hiddenChannels[]
  commentator_id  bigint REFERENCES commentators (id) ON DELETE SET NULL,  -- from: channelCommentators[ch].name
  commentator2_id bigint REFERENCES commentators (id) ON DELETE SET NULL,  -- from: channelCommentators[ch].name2
  created_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (match_id, channel_id),
  CONSTRAINT ck_match_channels_commentators CHECK (
    commentator2_id IS NULL OR (commentator_id IS NOT NULL AND commentator2_id <> commentator_id))
);
CREATE INDEX match_channels_channel_id_idx ON match_channels (channel_id);
CREATE INDEX match_channels_commentator_id_idx ON match_channels (commentator_id) WHERE commentator_id IS NOT NULL;
CREATE INDEX match_channels_commentator2_id_idx ON match_channels (commentator2_id) WHERE commentator2_id IS NOT NULL;

-- Free-text broadcasters shown before the channel list (used by sporteventz events).
-- from: broadcastOn/broadcastLogo (slot 1, commentator = match commentator),
--       broadcastOn2/broadcastLogo2/commentator2* (slot 2)
CREATE TABLE match_custom_broadcasts (
  match_id       bigint NOT NULL REFERENCES matches (id),
  slot           smallint NOT NULL CONSTRAINT ck_match_custom_broadcasts_slot CHECK (slot IN (1, 2)),
  label          text NOT NULL,
  logo_asset_id  bigint REFERENCES media_assets (id),
  commentator_id bigint REFERENCES commentators (id) ON DELETE SET NULL,
  PRIMARY KEY (match_id, slot)
);
CREATE INDEX match_custom_broadcasts_commentator_id_idx ON match_custom_broadcasts (commentator_id) WHERE commentator_id IS NOT NULL;

-- ─── Other content ──────────────────────────────────────────────────────────

-- Raw satellite feeds for a match. from: feeds (0 docs today; shape from the admin form)
-- Pending O3: until it is decided, lines hold tuning only, never BISS keys.
CREATE TABLE feeds (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  legacy_id          text UNIQUE,
  match_id           bigint REFERENCES matches (id),   -- MatchDetail.feed_id; NULL when no match row fits
  feed_date          date NOT NULL,             -- from: date
  home_team_name     text NOT NULL,             -- from: team1
  away_team_name     text NOT NULL,             -- from: team2
  home_logo_asset_id bigint REFERENCES media_assets (id),
  away_logo_asset_id bigint REFERENCES media_assets (id),
  lines              text[] NOT NULL DEFAULT '{}',   -- from: freqs[], free text ("Eutelsat 3.1°E - 10969 H 7500")
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_feeds_no_biss CHECK (array_to_string(lines, ' ') !~* 'biss')
);
CREATE INDEX feeds_feed_date_idx ON feeds (feed_date);
CREATE INDEX feeds_match_id_idx ON feeds (match_id) WHERE match_id IS NOT NULL;

-- One row per importer run; replaces settings/autoImport (last YallaKora run only).
-- settings/app.minVersion is not stored: Remote Config's min_supported_build replaces it (D11).
CREATE TABLE import_runs (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source           text NOT NULL REFERENCES sources (name),
  started_at       timestamptz NOT NULL DEFAULT now(),
  finished_at      timestamptz,
  matches_imported integer NOT NULL DEFAULT 0,
  error            text
);
CREATE INDEX import_runs_source_started_at_idx ON import_runs (source, started_at DESC);

-- ─── updated_at triggers ────────────────────────────────────────────────────

CREATE TRIGGER sources_set_updated_at        BEFORE UPDATE ON sources        FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER satellites_set_updated_at     BEFORE UPDATE ON satellites     FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER competitions_set_updated_at   BEFORE UPDATE ON competitions   FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER channels_set_updated_at       BEFORE UPDATE ON channels       FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER teams_set_updated_at          BEFORE UPDATE ON teams          FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER commentators_set_updated_at   BEFORE UPDATE ON commentators   FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER rights_holders_set_updated_at BEFORE UPDATE ON rights_holders FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER matches_set_updated_at        BEFORE UPDATE ON matches        FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER feeds_set_updated_at          BEFORE UPDATE ON feeds          FOR EACH ROW EXECUTE FUNCTION set_updated_at();
