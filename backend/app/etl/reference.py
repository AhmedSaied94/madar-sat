"""Reference data load: satellites, competitions, teams, commentators, presets,
hidden names and LiveSoccerTV teams (README rules 4, 12–15, 17)."""

from __future__ import annotations

import re
import unicodedata
from datetime import datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session

from app.db.models import (
    BroadcastPreset,
    Commentator,
    Competition,
    HiddenChannelName,
    LivesoccertvTeam,
    Satellite,
    Team,
    TeamCompetition,
    TeamExternalId,
)
from app.domain.arabic import ar_normalize
from app.domain.frequency import parse_frequency
from app.etl.report import Report
from app.etl.types import Context, Snapshot

_ORBITAL_RE = re.compile(r"(\d+(?:\.\d+)?)([EW])$")
_NON_ALNUM_RE = re.compile(r"[^a-z0-9]+")


def make_slug(name_en: str) -> str:
    s = unicodedata.normalize("NFKD", name_en)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    s = s.lower()
    return _NON_ALNUM_RE.sub("-", s).strip("-")


def satellite_name_en(raw_en: str) -> str:
    en = raw_en.strip()
    if raw_en != raw_en.strip() and en == "Eutel 16.0E":
        return "Eutel 16.0E Africa"
    return en


def parse_orbital(name_en: str) -> float | None:
    m = _ORBITAL_RE.search(name_en)
    if not m:
        return None
    value = float(m.group(1))
    return -value if m.group(2) == "W" else value


def _upsert_legacy_id(session: Session, model: Any, legacy_id: str) -> tuple[Any, bool]:
    existing = session.execute(select(model).where(model.legacy_id == legacy_id)).scalar_one_or_none()
    if existing is not None:
        return existing, False
    obj = model(legacy_id=legacy_id)
    session.add(obj)
    return obj, True


def _satellite_tuning(value: str | None, report: Report, ref: str) -> tuple[int | None, str | None, int | None]:
    if not value:
        return None, None, None
    freq, reason = parse_frequency(value)
    if freq is None:
        report.warn("satellite_frequency_missing_polarization", ref, value)
        return None, None, None
    return freq.mhz, freq.pol, freq.sr


def load(session: Session, snapshot: Snapshot, report: Report, ctx: Context) -> None:
    _load_satellites(session, snapshot, report, ctx)
    _load_competitions(session, snapshot, report, ctx)
    _load_teams(session, snapshot, report, ctx)
    _load_commentators(session, snapshot, report, ctx)
    _load_presets_and_hidden(session, snapshot, report, ctx)
    _load_livesoccertv(session, snapshot, report, ctx)


def _load_satellites(session: Session, snapshot: Snapshot, report: Report, ctx: Context) -> None:
    stats = report.collection("satellites")
    stats.source_rows = len(snapshot.satellites)
    # satPriority lists the raw names, so " Eutel 16.0E" (Africa) has its own entry.
    priority = {name: i for i, name in enumerate(snapshot.order("satPriority"))}
    kinds: dict[str, int] = {}

    for src in snapshot.satellites:
        raw_en = src.get("en", "")
        name_en = satellite_name_en(raw_en)
        kind = "terrestrial" if name_en == "DVB T2" else "satellite"
        kinds[kind] = kinds.get(kind, 0) + 1
        # Parse the position from the raw name (the Africa rename moves the
        # "16.0E" away from the end of the string).
        orbital = parse_orbital(raw_en.strip()) if kind == "satellite" else None

        sat, _ = _upsert_legacy_id(session, Satellite, src["id"])
        sat.slug = make_slug(name_en)
        sat.kind = kind
        sat.name_en = name_en
        sat.name_ar = src.get("ar", "")
        sat.orbital_position = orbital
        sat.reception_url = src.get("receptionUrl") or None
        sat.priority = priority.get(raw_en)
        sat.best_frequency_mhz, sat.best_polarization, sat.best_symbol_rate = _satellite_tuning(
            src.get("bestFreq"), report, f"{name_en} bestFreq"
        )
        sat.worst_frequency_mhz, sat.worst_polarization, sat.worst_symbol_rate = _satellite_tuning(
            src.get("worstFreq"), report, f"{name_en} worstFreq"
        )
        session.flush()
        stats.loaded += 1
        ctx.satellites_by_legacy_id[src["id"]] = sat.id
        ctx.satellites_by_name_en[raw_en] = sat.id

    report.kinds["satellites"] = kinds


def _load_competitions(session: Session, snapshot: Snapshot, report: Report, ctx: Context) -> None:
    stats = report.collection("competitions")
    stats.source_rows = len(snapshot.competitions)
    priority = {name: i for i, name in enumerate(snapshot.order("compPriority"))}

    for src in snapshot.competitions:
        comp, _ = _upsert_legacy_id(session, Competition, src["id"])
        comp.sport = "football"
        comp.name = src["name"]
        comp.priority = priority.get(src["name"])
        session.flush()
        stats.loaded += 1
        ctx.competitions_by_legacy_id[src["id"]] = comp.id
        ctx.competitions_by_name_norm[ar_normalize(src["name"])] = comp.id


def _resolve_competition(ctx: Context, name: str | None) -> int | None:
    if not name:
        return None
    return ctx.competitions_by_name_norm.get(ar_normalize(name))


def _load_teams(session: Session, snapshot: Snapshot, report: Report, ctx: Context) -> None:
    stats = report.collection("teams")
    stats.source_rows = len(snapshot.teams)
    seen_ysids: set[str] = set()

    for src in snapshot.teams:
        team, _ = _upsert_legacy_id(session, Team, src["id"])
        team.sport = "football"
        team.name = src["name"]
        team.country = None
        team.stadium = src.get("stadium") or None
        primary = _resolve_competition(ctx, src.get("league"))
        if src.get("league") and primary is None:
            report.warn("team_primary_competition_unresolved", src["id"], src.get("league", ""))
        team.primary_competition_id = primary
        session.flush()
        stats.loaded += 1
        ctx.teams_by_legacy_id[src["id"]] = team.id
        ctx.teams_by_name_norm.setdefault(ar_normalize(src["name"]), []).append(team.id)

        ys_id = str(src.get("ysId") or "")
        if ys_id:
            if ys_id in seen_ysids:
                # README rule 13: the id stays on the first team; log the second for the merge tool.
                report.warn("team_external_id_duplicate", src["id"], f"ysscores {ys_id}")
            else:
                seen_ysids.add(ys_id)
                stmt = pg_insert(TeamExternalId).values(source="ysscores", external_id=ys_id, team_id=team.id)
                session.execute(
                    stmt.on_conflict_do_update(
                        index_elements=["source", "external_id"], set_={"team_id": stmt.excluded.team_id}
                    )
                )

        for league_name in src.get("leagues") or []:
            comp_id = _resolve_competition(ctx, league_name)
            if comp_id is not None:
                session.execute(
                    pg_insert(TeamCompetition).values(team_id=team.id, competition_id=comp_id).on_conflict_do_nothing()
                )


def _load_commentators(session: Session, snapshot: Snapshot, report: Report, ctx: Context) -> None:
    stats = report.collection("commentators")
    doc = snapshot.setting("commentators") or {}
    src_list = doc.get("list", [])
    stats.source_rows = len(src_list)
    first_name: dict[str, str] = {}

    for src in src_list:
        name = src["name"]
        norm = ar_normalize(name)
        if norm in first_name:  # unique per name_norm (README rule 15)
            report.merged("commentators", name, "duplicate_name", first_name[norm])
            continue
        first_name[norm] = name
        existing = session.execute(select(Commentator).where(Commentator.name_norm == norm)).scalar_one_or_none()
        if existing is None:
            existing = Commentator(name=name)
            session.add(existing)
            session.flush()
        stats.loaded += 1
        ctx.commentators_by_name_norm[norm] = existing.id


def _load_presets_and_hidden(session: Session, snapshot: Snapshot, report: Report, ctx: Context) -> None:
    presets = report.collection("broadcast_presets")
    doc = snapshot.setting("broadcasts") or {}
    src_list = doc.get("list", [])
    presets.source_rows = len(src_list)
    seen_presets: set[str] = set()
    for src in src_list:
        if src["name"] in seen_presets:
            report.merged("broadcast_presets", src["name"], "duplicate_name", src["name"])
            continue
        seen_presets.add(src["name"])
        session.execute(pg_insert(BroadcastPreset).values(name=src["name"]).on_conflict_do_nothing())
        presets.loaded += 1

    hidden = report.collection("hidden_channel_names")
    names = (snapshot.setting("autoHiddenChannels") or {}).get("names", [])
    hidden.source_rows = len(names)
    seen_hidden: dict[str, str] = {}
    for name in names:
        normalized = ar_normalize(name)
        if normalized in seen_hidden:
            report.merged("hidden_channel_names", name, "duplicate_name", seen_hidden[normalized])
            continue
        seen_hidden[normalized] = name
        session.execute(pg_insert(HiddenChannelName).values(name=normalized).on_conflict_do_nothing())
        hidden.loaded += 1


def _load_livesoccertv(session: Session, snapshot: Snapshot, report: Report, ctx: Context) -> None:
    stats = report.collection("livesoccertv_teams")
    stats.source_rows = len(snapshot.team_dict)

    for src in snapshot.team_dict:
        ar_name = src.get("ar") or src.get("id") or ""
        existing = session.execute(
            select(LivesoccertvTeam).where(
                LivesoccertvTeam.ar_name == ar_name,
                LivesoccertvTeam.country.is_not_distinct_from(src.get("country") or None),
                LivesoccertvTeam.slug == src.get("slug", ""),
            )
        ).scalar_one_or_none()
        if existing is None:
            existing = LivesoccertvTeam(
                ar_name=ar_name,
                country=src.get("country") or None,
                slug=src.get("slug", ""),
            )
            session.add(existing)
        existing.en_name = src.get("en", "")
        existing.saved_at = _parse_dt(src.get("savedAt"))

        matches = ctx.teams_by_name_norm.get(ar_normalize(ar_name), [])
        existing.team_id = matches[0] if len(matches) == 1 else None
        session.flush()
        stats.loaded += 1


def _parse_dt(value: str | None) -> datetime | None:
    if not value:
        return None
    return datetime.fromisoformat(value.replace("Z", "+00:00"))
