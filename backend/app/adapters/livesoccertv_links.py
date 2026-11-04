"""LiveSoccerTV's channel matching, placeholders and link rules (R15, R18; T062).

The port of ``saveChannelsToMatch`` (``../old_app/public/LVS.html`` lines 861–930) onto Madar's
tables, under the rules the spec keeps:

- the names are normalized with :func:`app.domain.arabic.ar_normalize` (the same function as the
  ``name_norm`` column) and de-duplicated by name, unless a Madar channel with that name has a
  country: then each listing country is matched separately;
- a name that matches an existing channel (``name_norm`` or display name, not soft-deleted) is
  linked **whatever country lists it**;
- a name from a configured country that matches nothing becomes one hidden **placeholder**
  (``kind = 'platform'``, ``show_in_match = false``, ``placeholder_source = 'livesoccertv'``) and is
  linked; a soft-deleted one means an editor rejected it, so nothing is created;
- a name from an unlisted country that matches nothing is skipped and counted in the run;
- only rows whose ``source`` is ``livesoccertv`` are added or removed. An editor's edit or removal
  makes a row ``manual`` (D2 FR-008), which this module never touches again.

Revision ``0005`` (Lane B1) adds ``channels.placeholder_source``; the insert names the column in SQL
rather than through ``app.db.models``, which Lane B1 owns.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass, field
from typing import Any

from sqlalchemy import func, or_, select, text

from app.adapters.config import countries_match, get_adapter_settings, normalize_country
from app.adapters.health import bump_datasets
from app.adapters.messages import BroadcastChannel
from app.adapters.resolve import CHANNEL_ALIAS_SQL
from app.adapters.unresolved import record_unresolved
from app.db.models import AuditLog, Channel, Match, MatchChannel
from app.domain.arabic import ar_normalize

SOURCE = "livesoccertv"
PLACEHOLDER_SQL = """
INSERT INTO channels (kind, name, country, show_in_match, placeholder_source)
VALUES ('platform', :name, :country, false, :source)
RETURNING id
"""


@dataclass(slots=True)
class LinkOutcome:
    """What one match's channel list did, for the compact run log (A13)."""

    added: list[int] = field(default_factory=list)
    removed: list[int] = field(default_factory=list)
    placeholders_created: list[str] = field(default_factory=list)
    skipped: list[dict[str, str]] = field(default_factory=list)
    names_queued: int = 0
    # The datasets this outcome changes, so a caller that sequences the bumps knows which.
    datasets: list[str] = field(default_factory=list)

    def as_log(self) -> dict[str, Any]:
        return {
            "placeholders_created": list(self.placeholders_created),
            "links_added": len(self.added),
            "links_removed": len(self.removed),
            "skipped_channels": self.skipped[:20],
            "skipped_count": len(self.skipped),
        }


@dataclass(frozen=True, slots=True)
class _Row:
    """The columns the matcher reads from ``channels``."""

    id: int
    name_norm: str
    display_name: str | None
    country: str | None
    deleted: bool
    placeholder: bool = False


def _rows_for(session: Any, normal: str, name: str) -> list[_Row]:
    looked_up = name.strip().lower()
    rows = session.execute(
        select(
            Channel.id,
            Channel.name_norm,
            Channel.display_name,
            Channel.country,
            Channel.deleted_at,
            Channel.placeholder_source,
        ).where(
            or_(
                Channel.name_norm == normal,
                func.lower(func.trim(Channel.display_name)) == looked_up,
            )
        )
    ).all()
    return [
        _Row(
            id=row[0],
            name_norm=row[1],
            display_name=row[2],
            country=row[3],
            deleted=row[4] is not None,
            placeholder=row[5] is not None,
        )
        for row in rows
    ]


def _configured(countries: Sequence[str] | None) -> tuple[str, ...]:
    if countries is None:
        return get_adapter_settings().countries()
    return tuple(normalize_country(country) for country in countries if normalize_country(country))


def apply_broadcasts(
    session: Any,
    *,
    match_id: int,
    channels: Sequence[BroadcastChannel],
    countries: Sequence[str] | None = None,
    bump: bool = True,
) -> LinkOutcome:
    """Link one match's broadcasters, creating hidden placeholders where Madar has no channel.

    ``bump=False`` leaves the dataset versions to the caller, which bumps them as the last write of
    its own transaction (an ingest writes its run log and the source health first).
    """
    outcome = LinkOutcome()
    configured = _configured(countries)
    cache: dict[str, list[_Row]] = {}
    entries: list[tuple[str, str]] = []  # (name, listed country)
    seen_name_only: set[str] = set()
    desired: list[int] = []
    linked: set[int] = set()

    for channel in channels:
        name = channel.name.strip()
        normal = ar_normalize(name)
        if not normal:
            continue
        # An editor's mapping comes first (D5 T054); a placeholder made before it is simply unused.
        alias = session.execute(text(CHANNEL_ALIAS_SQL), {"source": SOURCE, "alias": normal}).scalar_one_or_none()
        if alias is not None:
            if alias not in linked:
                linked.add(alias)
                desired.append(alias)
            continue
        if normal not in cache:
            cache[normal] = _rows_for(session, normal, name)
        live = [row for row in cache[normal] if not row.deleted]
        if any(row.country for row in live):
            entries.append((name, channel.country))
            continue
        if normal in seen_name_only:
            continue
        seen_name_only.add(normal)
        entries.append((name, channel.country))

    queued: set[str] = set()
    for name, listed_country in entries:
        normal = ar_normalize(name)
        rows = cache.get(normal) or _rows_for(session, normal, name)
        cache[normal] = rows
        live = [row for row in rows if not row.deleted]
        with_country = [row for row in live if row.country]
        if live and all(row.placeholder for row in live) and normal not in queued:
            queued.add(normal)
            _queue_channel(session, match_id, name, outcome)
        if with_country:
            matched = [row for row in with_country if countries_match(row.country, listed_country)]
            candidates = matched or with_country
        elif live:
            candidates = live
        else:
            channel_id = _placeholder(session, name, listed_country, configured, rows, outcome)
            if channel_id is None:
                continue
            candidates = [
                _Row(id=channel_id, name_norm=normal, display_name=None, country=None, deleted=False, placeholder=True)
            ]
            cache[normal] = rows + candidates
            if normal not in queued:
                queued.add(normal)
                _queue_channel(session, match_id, name, outcome)
        for row in candidates:
            if row.id not in linked:
                linked.add(row.id)
                desired.append(row.id)

    _reconcile_links(session, match_id=match_id, desired=desired, outcome=outcome)
    outcome.datasets = _datasets(outcome)
    if bump:
        bump_datasets(session, outcome.datasets)
    return outcome


def _datasets(outcome: LinkOutcome) -> list[str]:
    """Which datasets a match's links changed: ``channels`` for a placeholder, ``matches`` for a link."""
    names = ["channels"] if outcome.placeholders_created else []
    if outcome.added or outcome.removed:
        names.append("matches")
    if outcome.names_queued:
        names.append("unresolved_names")
    return names


def _queue_channel(session: Any, match_id: int, name: str, outcome: LinkOutcome) -> None:
    """A placeholder holds the link and the queue holds the question: both stay (D5 R11)."""
    row = session.execute(
        select(Match.home_team_name, Match.away_team_name, Match.competition_name, Match.kickoff_at).where(
            Match.id == match_id
        )
    ).one()
    context = {"match_id": match_id, "home": row[0], "away": row[1], "competition": row[2], "kickoff_at": row[3]}
    if record_unresolved(session, source=SOURCE, kind="channel", name=name, competition=None, context=context):
        outcome.names_queued += 1


def _placeholder(
    session: Any,
    name: str,
    listed_country: str,
    configured: Sequence[str],
    existing: Sequence[_Row],
    outcome: LinkOutcome,
) -> int | None:
    """Create one hidden placeholder, or report why the name is skipped (R18)."""
    country = normalize_country(listed_country)
    if any(row.deleted for row in existing):
        # An editor rejected this name once: never recreate it (R18).
        outcome.skipped.append({"name": name, "country": country, "why": "deleted_by_editor"})
        return None
    if not country:
        outcome.skipped.append({"name": name, "country": "", "why": "no_country"})
        return None
    if country not in configured:
        outcome.skipped.append({"name": name, "country": country, "why": "country_not_listed"})
        return None
    channel_id = int(
        session.execute(text(PLACEHOLDER_SQL), {"name": name, "country": country, "source": SOURCE}).scalar_one()
    )
    session.add(
        AuditLog(
            admin_user_id=None,
            source=SOURCE,
            entity="channels",
            entity_id=channel_id,
            action="create",
            diff={"name": name, "country": country, "placeholder_source": SOURCE},
        )
    )
    outcome.placeholders_created.append(name)
    return channel_id


def _reconcile_links(session: Any, *, match_id: int, desired: Sequence[int], outcome: LinkOutcome) -> None:
    """Add what the page lists and remove only what it no longer lists, for our own rows."""
    existing = {
        row.channel_id: row
        for row in session.execute(select(MatchChannel).where(MatchChannel.match_id == match_id)).scalars()
    }
    wanted = set(desired)
    for channel_id, row in existing.items():
        if row.source != SOURCE:
            continue  # manual links and other importers' links are never touched (FR-008)
        if channel_id not in wanted:
            session.delete(row)
            outcome.removed.append(channel_id)
    for channel_id in desired:
        if channel_id in existing:
            continue
        session.add(
            MatchChannel(
                match_id=match_id,
                channel_id=channel_id,
                source=SOURCE,
                imported_by=SOURCE,
                is_hidden=False,
            )
        )
        outcome.added.append(channel_id)
    outcome.added = sorted(set(outcome.added))
    outcome.removed = sorted(set(outcome.removed))
