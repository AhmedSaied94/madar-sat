"""Match create and update: the A4 editor's save (research R7, FR-005 to FR-011).

``update`` applies the sections of a ``MatchPatch`` (``fields``, ``broadcasts``, ``channels``, ``status``)
under one ``If-Match`` and writes one audit row. Everything is validated before the first row changes, so
a refused save writes nothing.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.roles import AuthedAdmin
from app.db.models import Commentator, Competition, Match, Team
from app.domain import manual_status
from app.domain.lockable import MATCH_LOCKABLE, STATUS_COLUMNS
from app.domain.time import CAIRO
from app.schemas import admin as a
from app.services.admin import match_links, refs, versions, writer
from app.services.admin.match_view import ENTITY, NOT_FOUND

Error = dict[str, Any]

# A change to one of these is visible on /v1/live, so that dataset is bumped as well.
LIVE_KEYS = frozenset(
    {
        "kickoff_at",
        "time_tbd",
        "status",
        "status_source",
        "period",
        "minute",
        "home_score",
        "away_score",
        "home_pen",
        "away_pen",
        "status_label",
    }
)


def datasets_for(changed: set[str]) -> tuple[str, ...]:
    return ("matches", "live") if changed & LIVE_KEYS else ("matches",)


def _error(loc: list[str | int], reason: str) -> Error:
    return refs.field_error(loc, reason)


# --- fields ---------------------------------------------------------------------------------------


def _apply_kickoff(match: Match, fields: a.MatchFields, errors: list[Error]) -> None:
    sent = fields.model_fields_set
    if not {"kickoff_at", "time_tbd", "match_date"} & sent:
        return

    kickoff = match.kickoff_at
    if "kickoff_at" in sent:
        kickoff = fields.kickoff_at
    if fields.time_tbd is True:
        kickoff = None
    if fields.time_tbd is False and kickoff is None:
        errors.append(_error(["fields", "kickoff_at"], "kickoff_required"))
        return

    match.kickoff_at = kickoff
    match.time_tbd = kickoff is None
    if kickoff is not None:
        cairo_date = kickoff.astimezone(CAIRO).date()
        if fields.match_date is not None and fields.match_date != cairo_date:
            errors.append(_error(["fields", "match_date"], "match_date_mismatch"))
        match.match_date = cairo_date
    elif "match_date" in sent:
        if fields.match_date is None:
            errors.append(_error(["fields", "match_date"], "null_not_allowed"))
        else:
            match.match_date = fields.match_date


async def _apply_competition(session: AsyncSession, match: Match, fields: a.MatchFields, errors: list[Error]) -> None:
    sent = fields.model_fields_set
    if not {"competition_id", "competition_name"} & sent:
        return

    if fields.competition_id is not None:
        competition = await session.get(Competition, fields.competition_id)
        if competition is None:
            errors.append(_error(["fields", "competition_id"], "not_found"))
            return
        match.competition_id, match.competition_name = competition.id, competition.name
    elif fields.competition_name is not None:
        match.competition_id, match.competition_name = None, fields.competition_name
    elif "competition_name" in sent:
        errors.append(_error(["fields", "competition_name"], "null_not_allowed"))
    else:
        match.competition_id = None  # only competition_id: null was sent; the text stays


async def _apply_team(
    session: AsyncSession, match: Match, side: str, team: a.TeamInput | None, errors: list[Error]
) -> None:
    if team is None:
        errors.append(_error(["fields", side], "null_not_allowed"))
        return
    if team.team_id is not None:
        row = await session.get(Team, team.team_id)
        if row is None:
            errors.append(_error(["fields", side, "team_id"], "not_found"))
            return
        new_id: int | None = row.id
        new_name = row.name
    else:
        new_id, new_name = None, team.name or ""  # TeamInput guarantees a name when there is no team_id

    if (getattr(match, f"{side}_team_id"), getattr(match, f"{side}_team_name")) != (new_id, new_name):
        setattr(match, f"{side}_logo_asset_id", None)  # the old logo belonged to the old team
    setattr(match, f"{side}_team_id", new_id)
    setattr(match, f"{side}_team_name", new_name)


async def apply_fields(session: AsyncSession, match: Match, fields: a.MatchFields, errors: list[Error]) -> None:
    sent = fields.model_fields_set
    _apply_kickoff(match, fields, errors)
    await _apply_competition(session, match, fields, errors)
    for side in ("home", "away"):
        if side in sent:
            await _apply_team(session, match, side, getattr(fields, side), errors)
    if "competition_stage" in sent:
        match.competition_stage = fields.competition_stage
    if "stadium" in sent:
        match.stadium = fields.stadium
    if "commentator_id" in sent:
        if fields.commentator_id is not None and await session.get(Commentator, fields.commentator_id) is None:
            errors.append(_error(["fields", "commentator_id"], "not_found"))
        else:
            match.commentator_id = fields.commentator_id


def supplied_lockable(fields: a.MatchFields) -> set[str]:
    """The lockable columns an editor supplied, through the names their input maps to (B1-R1-4).

    ``create`` builds its ``MatchFields`` with every key, so a ``None`` value here means "not sent".
    """
    sent = {name for name in fields.model_fields_set if getattr(fields, name) is not None}
    names: set[str] = set()
    if {"kickoff_at", "time_tbd"} & sent:
        names.add("kickoff_at")
    if {"competition_id", "competition_name"} & sent:
        names |= {"competition_id", "competition_name"}
    for side in ("home", "away"):
        if side in sent:
            names |= {f"{side}_team_id", f"{side}_team_name"}
    names |= {column for column in ("competition_stage", "stadium", "commentator_id") if column in sent}
    return names


# --- manual status ----------------------------------------------------------------------------------


def apply_status(match: Match, patch: a.StatusPatch, now: datetime, errors: list[Error]) -> frozenset[str]:
    """Set or clear the manual status. Returns the columns that must not be locked afterwards."""
    if patch.set is None:
        wanted: dict[str, Any] = {
            "status_source": "clock",
            "status": "scheduled",
            "period": None,
            "minute": None,
            "home_score": None,
            "away_score": None,
            "home_pen": None,
            "away_pen": None,
            "status_label": None,
        }
        _store_status(match, wanted, status_updated_at=None)
        return STATUS_COLUMNS

    status = patch.set
    problems = manual_status.validate(
        status.status.value,
        status.period.value if status.period else None,
        status.minute,
        status.score,
        status.status_label,
    )
    if problems:
        errors += [{"loc": ["body", "status", "set", *p["loc"]], "type": p["type"]} for p in problems]  # type: ignore[misc]
        return frozenset()

    score = status.score
    wanted = {
        "status_source": "manual",
        "status": status.status.value,
        "period": status.period.value if status.period else None,
        "minute": status.minute,
        "home_score": score.home if score else None,
        "away_score": score.away if score else None,
        "home_pen": score.home_pen if score else None,
        "away_pen": score.away_pen if score else None,
        "status_label": status.status_label,
    }
    _store_status(match, wanted, status_updated_at=now)
    return frozenset()


def _store_status(match: Match, wanted: dict[str, Any], status_updated_at: datetime | None) -> None:
    """Write the status columns; ``status_updated_at`` moves only when something actually changed."""
    changed = any(getattr(match, column) != value for column, value in wanted.items())
    for column, value in wanted.items():
        setattr(match, column, value)
    if changed:
        match.status_updated_at = status_updated_at


# --- update and create -------------------------------------------------------------------------------


async def update(
    session: AsyncSession,
    admin: AuthedAdmin,
    match_id: int,
    body: a.MatchPatch,
    if_match: str | None,
    now: datetime,
) -> Match:
    match = await writer.lock_and_check(session, Match, match_id, NOT_FOUND, ENTITY, if_match)
    before = versions.row_state(match)

    errors: list[Error] = []
    if body.channels is not None:
        errors += await match_links.link_errors(session, body.channels)
    if body.broadcasts is not None:
        errors += await match_links.slot_errors(session, body.broadcasts)
    if body.fields is not None:
        await apply_fields(session, match, body.fields, errors)
    unlock: frozenset[str] = frozenset()
    if body.status is not None:
        unlock = apply_status(match, body.status, now, errors)
    refs.raise_if_any(errors)

    extra: dict[str, Any] = {}
    if body.broadcasts is not None:
        slots = await match_links.reconcile_slots(session, match.id, body.broadcasts)
        if slots:
            extra["broadcasts"] = slots
            # Slots aren't columns, so ``lock_changed_fields`` can't see them: lock the value by hand,
            # or an importer would wipe an editor's entries (research R23).
            match.locked_fields = sorted({*(match.locked_fields or []), "broadcasts"})
    if body.channels is not None:
        links = await match_links.reconcile_links(session, match.id, body.channels)
        if links:
            extra["channels"] = links

    await writer.save_update(
        session,
        admin,
        entity=ENTITY,
        row=match,
        before=before,
        datasets=datasets_for,
        now=now,
        lockable=MATCH_LOCKABLE - unlock,
        extra_diff=extra,
    )
    if unlock:
        match.locked_fields = [name for name in (match.locked_fields or []) if name not in unlock]
    return match


async def create(session: AsyncSession, admin: AuthedAdmin, body: a.MatchCreate, now: datetime) -> Match:
    """A new manual match. The fields the editor supplied are locked, or the next import could take it over."""
    errors: list[Error] = await match_links.link_errors(session, body.channels)
    errors += await match_links.slot_errors(session, body.broadcasts)

    match = Match(
        sport="football",
        source="manual",
        match_date=body.match_date,
        competition_name="",
        home_team_name="",
        away_team_name="",
        status="scheduled",
        status_source="clock",
        time_tbd=body.time_tbd,
        locked_fields=[],
        is_live=False,
    )
    fields = a.MatchFields(
        kickoff_at=body.kickoff_at,
        time_tbd=body.time_tbd,
        match_date=body.match_date,
        competition_id=body.competition_id,
        competition_name=body.competition_name,
        competition_stage=body.competition_stage,
        home=body.home,
        away=body.away,
        stadium=body.stadium,
        commentator_id=body.commentator_id,
    )
    await apply_fields(session, match, fields, errors)
    refs.raise_if_any(errors)
    writer.lock_changed_fields(match, supplied_lockable(fields), MATCH_LOCKABLE)

    session.add(match)
    await writer.flush(session)
    slots = await match_links.reconcile_slots(session, match.id, body.broadcasts)
    if slots:
        match.locked_fields = sorted({*(match.locked_fields or []), "broadcasts"})
    extra: dict[str, Any] = {"locked_fields": [None, list(match.locked_fields)]} if match.locked_fields else {}
    if slots:
        extra["broadcasts"] = slots
    links = await match_links.reconcile_links(session, match.id, body.channels)
    if links:
        extra["channels"] = links
    await writer.save_create(session, admin, entity=ENTITY, row=match, datasets=("matches", "live"), extra_diff=extra)
    return match
