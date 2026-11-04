"""The upsert pipeline both importers share (T073, R18, FR-022).

One fixture per savepoint, so a single bad item marks the run ``partial`` instead of failing it:

1. find the row: ``(source, external_id)``, the bridge's ``matches.legacy_id``, or the duplicate
   probe (the same resolved teams within 45 minutes, or the same normalized names on the same
   ``match_date`` when a team id is missing);
2. lock it with ``SELECT … FOR UPDATE`` and re-read ``locked_fields`` under the lock, so an admin
   save that commits just before the import is never overwritten;
3. write only unlocked fields whose value differs, and record the external id;
4. audit what changed with ``source`` set and ``admin_user_id`` NULL;
5. hand the caller the logos to rehost: the pipeline never stores a URL;
6. bump ``matches`` (and ``live`` when a kickoff changed) once, at the end of the run.

``match_channels`` follows the importer rules: insert with ``source = imported_by = <adapter>``,
delete only rows whose ``source`` is this adapter, and never touch a ``manual`` row.
"""

from __future__ import annotations

import logging
from collections.abc import Callable, Iterable, Sequence
from dataclasses import dataclass, field
from datetime import UTC, timedelta
from typing import Any, cast

from sqlalchemy import func, select, text, update
from sqlalchemy.orm import Session

from app.adapters.base import NormalizedFixture, ParsedFixture
from app.adapters.health import bump_datasets
from app.adapters.resolve import ResolveResult, resolve_competition, resolve_team
from app.adapters.unresolved import Kind, record_unresolved
from app.db.models import (
    AuditLog,
    Competition,
    DatasetVersion,
    Match,
    MatchChannel,
    MatchExternalId,
    Team,
)

log = logging.getLogger(__name__)

KICKOFF_TOLERANCE = timedelta(minutes=45)
SOURCES = ("ysscores", "legacy", "manual", "yallakora")


class SkipItem(Exception):
    """The item cannot be imported; the run records it and moves on."""

    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


@dataclass(frozen=True, slots=True)
class LogoJob:
    """One logo to rehost: the table it belongs to, the row, the URL and who found it."""

    entity: str  # "teams" | "competitions"
    entity_id: int
    url: str
    source: str


@dataclass
class RunOutcome:
    items_found: int = 0
    created: int = 0
    updated: int = 0
    unchanged: int = 0
    kickoff_changed: bool = False
    skipped: list[dict[str, str]] = field(default_factory=list)
    unresolved: list[dict[str, str | None]] = field(default_factory=list)
    names_queued: int = 0
    postponed: list[dict[str, str]] = field(default_factory=list)
    logo_jobs: list[LogoJob] = field(default_factory=list)

    @property
    def items_upserted(self) -> int:
        return self.created + self.updated

    @property
    def changed(self) -> bool:
        return self.created + self.updated > 0


class UpsertPipeline:
    """``run`` applies a run's fixtures; the caller owns the transaction and the run row."""

    def __init__(self, session: Session, *, source: str, media_hosts: Iterable[str] = ()) -> None:
        if source not in SOURCES:
            raise ValueError(f"unknown source {source!r}")
        self.session = session
        self.source = source
        self.media_hosts = frozenset(media_hosts)

    # --- the run ------------------------------------------------------------------------

    def run(
        self,
        items: Sequence[NormalizedFixture | ParsedFixture],
        normalize: Callable[[Any], NormalizedFixture] | None = None,
    ) -> RunOutcome:
        """Apply each item in its own savepoint.

        ``normalize`` runs inside that savepoint too, so a page value that can't become a fixture
        ("12:99 م") is one skipped item, not a failed run (B2-R1-12).
        """
        outcome = RunOutcome(items_found=len(items))
        for raw in items:
            try:
                with self.session.begin_nested():
                    item = normalize(raw) if normalize is not None else cast(NormalizedFixture, raw)
                    created, changed, kickoff_changed = self._apply(item, outcome)
            except SkipItem as exc:
                outcome.skipped.append(_skipped(raw, exc.reason))
                continue
            except Exception as exc:  # one bad item must not fail the run (R18); its savepoint is gone
                log.warning(
                    "item_failed",
                    extra={"ref": _ref(raw), "source": self.source, "why": repr(exc)},
                    exc_info=True,
                )
                outcome.skipped.append(_skipped(raw, "error"))
                continue
            if item.postponed:
                outcome.postponed.append({"ref": _ref(item)})
            if created:
                outcome.created += 1
            elif changed:
                outcome.updated += 1
            else:
                outcome.unchanged += 1
            outcome.kickoff_changed = outcome.kickoff_changed or kickoff_changed

        if outcome.changed:
            self._bump(outcome.kickoff_changed)
        if outcome.names_queued:
            bump_datasets(self.session, ["unresolved_names"])
        return outcome

    def _bump(self, kickoff_changed: bool) -> None:
        names = ["matches", "live"] if kickoff_changed else ["matches"]
        self.session.flush()
        self.session.execute(
            update(DatasetVersion)
            .where(DatasetVersion.name.in_(names))
            .values(version=DatasetVersion.version + 1, updated_at=func.now())
        )

    # --- one fixture --------------------------------------------------------------------

    def _apply(self, item: NormalizedFixture, outcome: RunOutcome) -> tuple[bool, bool, bool]:
        home, away = item.home, item.away
        if not home or not away:
            raise SkipItem("missing_teams")
        if item.external_id is None and item.legacy_id is None:
            raise SkipItem("missing_external_id")

        competition = resolve_competition(
            self.session, external_id=None, name=item.competition, sport=item.sport, source=self.source
        )
        home_team = resolve_team(
            self.session,
            external_id=item.home_external_id,
            name=home,
            sport=item.sport,
            competition_name=item.competition,
            source=self.source,
        )
        away_team = resolve_team(
            self.session,
            external_id=item.away_external_id,
            name=away,
            sport=item.sport,
            competition_name=item.competition,
            source=self.source,
        )
        for result in (home_team, away_team):
            if result.entity_id is None and result.name:
                outcome.unresolved.append(
                    {"name": result.name, "competition": item.competition, "match_ref": _ref(item)}
                )

        match_id, created = self._find_or_create(item, competition, home_team, away_team)
        self._queue_unresolved(match_id, item, competition, home_team, away_team, outcome)
        locked, changed_fields, kickoff_changed = self._write_fields(
            match_id, item, competition, home_team, away_team, created=created
        )
        broadcaster = self._write_broadcaster(match_id, item, locked)
        if broadcaster:
            changed_fields = {**changed_fields, "local_broadcaster_eg": broadcaster}
        # Only an adapter that supplied a link set may reconcile them (B2-R1-2, FR-022).
        link_changes: dict[str, Any] = {}
        if item.links is not None:
            link_changes = self._reconcile_links(match_id, item, created=created, outcome=outcome)
        self._record_external_ids(match_id, item)

        changed = created or bool(changed_fields) or bool(link_changes)
        if changed:
            diff: dict[str, Any] = dict(changed_fields)
            if link_changes:
                diff["channels"] = link_changes
            self.session.add(
                AuditLog(
                    admin_user_id=None,
                    source=self.source,
                    entity="matches",
                    entity_id=match_id,
                    action="create" if created else "update",
                    diff=diff,
                )
            )
        self._queue_logos(item, competition, home_team, away_team, outcome)
        _ = locked  # read under the lock; kept for the caller's logs
        return created, changed, kickoff_changed

    def _queue_unresolved(
        self,
        match_id: int,
        item: NormalizedFixture,
        competition: ResolveResult,
        home_team: ResolveResult,
        away_team: ResolveResult,
        outcome: RunOutcome,
    ) -> None:
        """What the run couldn't match waits for an editor; the match keeps its text names (FR-022)."""
        context = {
            "match_id": match_id,
            "home": item.home,
            "away": item.away,
            "competition": item.competition,
            "kickoff_at": item.kickoff_at,
        }
        unmatched: list[tuple[Kind, ResolveResult]] = [
            ("competition", competition),
            ("team", home_team),
            ("team", away_team),
        ]
        for kind, result in unmatched:
            if result.entity_id is not None or not result.name:
                continue
            if record_unresolved(
                self.session,
                source=self.source,
                kind=kind,
                name=result.name,
                competition=item.competition if kind == "team" else None,
                context=context,
            ):
                outcome.names_queued += 1

    def _write_broadcaster(self, match_id: int, item: NormalizedFixture, locked: frozenset[str]) -> list[Any] | None:
        """Write the Egyptian broadcaster unless locked: ``[before, after]``, or ``None`` unchanged.

        Revision ``0007`` (Lane B1) adds the column. A card with no channel says nothing about it,
        so it never clears a stored value.
        """
        wanted = item.local_broadcaster_eg
        if wanted is None or "local_broadcaster_eg" in locked:
            return None
        before = self.session.execute(
            text("SELECT local_broadcaster_eg FROM matches WHERE id = :id"), {"id": match_id}
        ).scalar_one()
        if before == wanted:
            return None
        self.session.execute(
            text("UPDATE matches SET local_broadcaster_eg = :value, updated_at = now() WHERE id = :id"),
            {"value": wanted, "id": match_id},
        )
        return [before, wanted]

    def _find_or_create(
        self,
        item: NormalizedFixture,
        competition: ResolveResult,
        home_team: ResolveResult,
        away_team: ResolveResult,
    ) -> tuple[int, bool]:
        found = self._find_match(item)
        if found is not None:
            return found, False
        match = Match(
            source=self.source,
            match_date=item.match_date,
            kickoff_at=item.kickoff_at,
            time_tbd=item.time_tbd,
            competition_id=competition.entity_id,
            competition_name=item.competition or "",
            competition_stage=item.stage,
            home_team_id=home_team.entity_id,
            home_team_name=item.home or "",
            away_team_id=away_team.entity_id,
            away_team_name=item.away or "",
            stadium=None,
            legacy_id=item.legacy_id if self.source == "legacy" else None,
        )
        self.session.add(match)
        self.session.flush()
        return match.id, True

    def _find_match(self, item: NormalizedFixture) -> int | None:
        if self.source == "legacy" and item.legacy_id:
            found = self.session.execute(select(Match.id).where(Match.legacy_id == item.legacy_id)).scalar_one_or_none()
            if found is not None:
                return found
        # The bridge records `ysMatchId` as an ysscores id, so the two sources converge (R19).
        for source, external_id in ((self.source, item.external_id), ("ysscores", item.ys_match_id)):
            if not external_id:
                continue
            found = self.session.execute(
                select(MatchExternalId.match_id).where(
                    MatchExternalId.source == source, MatchExternalId.external_id == external_id
                )
            ).scalar_one_or_none()
            if found is not None:
                return found
        return self._duplicate_probe(item)

    def _duplicate_probe(self, item: NormalizedFixture) -> int | None:
        """A fixture another source already holds: the same teams within 45 min, or the same names."""
        home_team_id = resolve_team(
            self.session,
            external_id=item.home_external_id,
            name=item.home,
            sport=item.sport,
            competition_name=item.competition,
            source=self.source,
        ).entity_id
        away_team_id = resolve_team(
            self.session,
            external_id=item.away_external_id,
            name=item.away,
            sport=item.sport,
            competition_name=item.competition,
            source=self.source,
        ).entity_id
        if home_team_id is not None and away_team_id is not None and item.kickoff_at is not None:
            window = timedelta(minutes=KICKOFF_TOLERANCE.total_seconds() // 60)
            return self.session.execute(
                select(Match.id)
                .where(
                    Match.home_team_id == home_team_id,
                    Match.away_team_id == away_team_id,
                    Match.kickoff_at.is_not(None),
                    Match.kickoff_at.between(item.kickoff_at - window, item.kickoff_at + window),
                )
                .order_by(Match.id)
                .limit(1)
            ).scalar_one_or_none()
        if home_team_id is None or away_team_id is None:
            home_norm = func.ar_normalize(item.home or "")
            away_norm = func.ar_normalize(item.away or "")
            return self.session.execute(
                select(Match.id)
                .where(
                    Match.match_date == item.match_date,
                    func.ar_normalize(Match.home_team_name) == home_norm,
                    func.ar_normalize(Match.away_team_name) == away_norm,
                )
                .order_by(Match.id)
                .limit(1)
            ).scalar_one_or_none()
        return None

    def _write_fields(
        self,
        match_id: int,
        item: NormalizedFixture,
        competition: ResolveResult,
        home_team: ResolveResult,
        away_team: ResolveResult,
        *,
        created: bool,
    ) -> tuple[frozenset[str], dict[str, Any], bool]:
        """Lock the row, re-read ``locked_fields``, write what differs: ``(locked, diff, kickoff_changed)``."""
        match = self.session.execute(
            select(Match).where(Match.id == match_id).with_for_update().execution_options(populate_existing=True)
        ).scalar_one()
        locked = frozenset(match.locked_fields or [])
        if created:
            return locked, {}, False

        # The bridge's own key: adopting a row changes its version, so it is audited like a field.
        identity: dict[str, Any] = {}
        if self.source == "legacy" and item.legacy_id and match.legacy_id != item.legacy_id:
            identity["legacy_id"] = [match.legacy_id, item.legacy_id]
            match.legacy_id = item.legacy_id

        if self._fields_are_frozen(match):
            # The bridge never overwrites a fixture ysscores owns (R19, FR-027).
            if identity:
                match.updated_at = func.now()
            return locked, identity, False

        # A locked kickoff wins, and `time_tbd` follows whatever kickoff ends up stored: the CHECK
        # `ck_matches_time_tbd` refuses the pair otherwise (B2-R1-11).
        kickoff = match.kickoff_at if "kickoff_at" in locked else item.kickoff_at
        wanted: dict[str, Any] = {
            "kickoff_at": kickoff,
            "time_tbd": kickoff is None,
            "competition_id": competition.entity_id,
            "competition_name": item.competition or "",
            "competition_stage": item.stage,
            "home_team_id": home_team.entity_id,
            "home_team_name": item.home or "",
            "away_team_id": away_team.entity_id,
            "away_team_name": item.away or "",
        }
        diff: dict[str, Any] = dict(identity)
        kickoff_changed = False
        for name, value in wanted.items():
            if name in locked:
                continue
            before = getattr(match, name)
            if before == value:
                continue
            # A team id that resolved to nothing must not erase one somebody set.
            if name in {"home_team_id", "away_team_id", "competition_id"} and value is None and before is not None:
                continue
            setattr(match, name, value)
            diff[name] = [_plain(before), _plain(value)]
            if name == "kickoff_at":
                kickoff_changed = True
        if diff:
            match.updated_at = func.now()
        return locked, diff, kickoff_changed

    def _fields_are_frozen(self, match: Match) -> bool:
        if self.source == "yallakora":
            # It adds the broadcaster and its id to a row another source holds, and leaves the rest:
            # two importers rewriting each other's spelling would stale every open editor (D5).
            return match.source != "yallakora"
        if self.source != "legacy":
            return False
        if match.source == "ysscores":
            return True
        owned = self.session.execute(
            select(func.count())
            .select_from(MatchExternalId)
            .where(MatchExternalId.match_id == match.id, MatchExternalId.source == "ysscores")
        ).scalar_one()
        return bool(owned)

    def _reconcile_links(
        self, match_id: int, item: NormalizedFixture, *, created: bool, outcome: RunOutcome
    ) -> dict[str, Any]:
        desired = self._desired_links(item, outcome)
        existing = {
            row.channel_id: row
            for row in self.session.execute(select(MatchChannel).where(MatchChannel.match_id == match_id)).scalars()
        }
        added: list[int] = []
        removed: list[int] = []
        changed: list[int] = []

        for channel_id, row in existing.items():
            if row.source != self.source:
                continue  # manual rows and another importer's rows are never touched
            wanted = desired.get(channel_id)
            if wanted is None:
                self.session.delete(row)
                removed.append(channel_id)
                continue
            hidden, commentator_id, commentator2_id = wanted
            if (row.is_hidden, row.commentator_id, row.commentator2_id) != (hidden, commentator_id, commentator2_id):
                row.is_hidden = hidden
                row.commentator_id = commentator_id
                row.commentator2_id = commentator2_id
                changed.append(channel_id)

        for channel_id, (hidden, commentator_id, commentator2_id) in desired.items():
            if channel_id in existing:
                continue
            self.session.add(
                MatchChannel(
                    match_id=match_id,
                    channel_id=channel_id,
                    source=self.source,
                    imported_by=self.source,
                    is_hidden=hidden,
                    commentator_id=commentator_id,
                    commentator2_id=commentator2_id,
                )
            )
            added.append(channel_id)

        if created:
            added = sorted(added)
        if not (added or removed or changed):
            return {}
        return {"added": sorted(added), "removed": sorted(removed), "changed": sorted(changed)}

    def _desired_links(
        self, item: NormalizedFixture, outcome: RunOutcome
    ) -> dict[int, tuple[bool, int | None, int | None]]:
        """``{channel_id: (hidden, commentator_id, commentator2_id)}`` from the item's references."""
        desired: dict[int, tuple[bool, int | None, int | None]] = {}
        for link in item.links or ():
            channel = self._channel_id(link.channel_ref)
            if channel is None:
                # The old data names a channel Madar doesn't have: recorded, so run.json shows it (R19).
                outcome.skipped.append({"ref": link.channel_ref, "reason": "channel_not_published"})
                continue
            first = self._commentator_id(link.commentator)
            second = self._commentator_id(link.commentator2)
            if second is not None and (first is None or second == first):
                second = None
            desired[channel] = (link.hidden, first, second)
        return desired

    def _channel_id(self, legacy_id: str) -> int | None:
        from app.db.models import Channel

        return self.session.execute(select(Channel.id).where(Channel.legacy_id == legacy_id)).scalar_one_or_none()

    def _commentator_id(self, name: str | None) -> int | None:
        """``name_norm`` lookup, creating the commentator when the name is new (R19)."""
        if not name:
            return None
        from app.db.models import Commentator
        from app.domain.arabic import ar_normalize

        normal = ar_normalize(name)
        found = self.session.execute(
            select(Commentator.id).where(Commentator.name_norm == normal).limit(1)
        ).scalar_one_or_none()
        if found is not None:
            return found
        commentator = Commentator(name=name)
        self.session.add(commentator)
        self.session.flush()
        return commentator.id

    def _record_external_ids(self, match_id: int, item: NormalizedFixture) -> None:
        pairs: list[tuple[str, str | None, str | None]] = [(self.source, item.external_id, item.url)]
        if self.source == "legacy":
            pairs.append(("ysscores", item.ys_match_id, None))
            if item.legacy_id:
                self.session.execute(update(Match).where(Match.id == match_id).values(legacy_id=item.legacy_id))
        for source, external_id, url in pairs:
            if not external_id:
                continue
            existing = self.session.get(MatchExternalId, (source, external_id))
            if existing is None:
                self.session.add(MatchExternalId(source=source, external_id=external_id, match_id=match_id, url=url))
            elif existing.match_id != match_id:
                existing.match_id = match_id
            elif url and existing.url != url:
                existing.url = url

    def _queue_logos(
        self,
        item: NormalizedFixture,
        competition: ResolveResult,
        home_team: ResolveResult,
        away_team: ResolveResult,
        outcome: RunOutcome,
    ) -> None:
        """A resolved team or competition with no logo and an allowlisted URL is rehosted later (R20)."""
        candidates: list[tuple[str, int | None, str | None]] = [
            ("competitions", competition.entity_id, item.competition_logo),
            ("teams", home_team.entity_id, item.home_logo),
            ("teams", away_team.entity_id, item.away_logo),
        ]
        for entity, entity_id, url in candidates:
            if entity_id is None or not url:
                continue
            if self.media_hosts and _host(url) not in self.media_hosts:
                continue
            if not self._logo_is_empty(entity, entity_id):
                continue  # an existing logo is never replaced
            job = LogoJob(entity=entity, entity_id=entity_id, url=url, source=self.source)
            if all(not (j.entity == job.entity and j.entity_id == job.entity_id) for j in outcome.logo_jobs):
                outcome.logo_jobs.append(job)

    def _logo_is_empty(self, entity: str, entity_id: int) -> bool:
        model = Team if entity == "teams" else Competition
        logo = self.session.execute(select(model.logo_asset_id).where(model.id == entity_id)).scalar_one_or_none()
        return logo is None


def _plain(value: Any) -> Any:
    """A JSON-safe value for ``audit_log.diff`` (JSONB refuses a ``datetime``)."""
    from datetime import date, datetime
    from decimal import Decimal

    if isinstance(value, datetime):
        return value.astimezone(UTC).isoformat()
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, Decimal):
        return format(value.normalize(), "f")
    return value


def _host(url: str) -> str:
    from urllib.parse import urlsplit

    return urlsplit(url).hostname or ""


def _skipped(item: NormalizedFixture | ParsedFixture, reason: str) -> dict[str, str]:
    return {"ref": _ref(item), "reason": reason}


def _ref(item: NormalizedFixture | ParsedFixture) -> str:
    return item.external_id or item.legacy_id or (item.url or "?")
