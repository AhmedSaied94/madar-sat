"""Matches, their link tables and feeds (README rules 3, 4, 6–8, 11)."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Any
from urllib.parse import urlsplit

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session

from app.db.models import (
    Commentator,
    Feed,
    Match,
    MatchChannel,
    MatchCustomBroadcast,
    MatchExternalId,
    Team,
    TeamCompetition,
)
from app.domain.arabic import ar_normalize
from app.domain.time import CAIRO, cairo_to_utc, parse_cairo_wall_clock
from app.etl.checks import find_card_sharing_label
from app.etl.report import Report
from app.etl.types import Context, Snapshot

_NOT_LISTED = ar_normalize("غير مدرج")  # the commentator placeholder (README rule 6)


@dataclass
class Listing:
    """One source match listing (a matchDays[].matches[] entry)."""

    src: dict[str, Any]
    match_date: date
    kickoff_at: datetime | None
    position: int  # order in the snapshot, for deterministic tie-breaks
    merged_into: Listing | None = None
    extras: list[Listing] = field(default_factory=list)  # duplicate listings merged into this one

    @property
    def legacy_id(self) -> str:
        legacy_id: str = self.src["id"]
        return legacy_id


@dataclass
class LinkDraft:
    """A match_channels row being built from one or more channelIds entries."""

    ref: str  # "<listing>/<channel legacy id>" of the first entry
    listing: str
    source: str
    is_hidden: bool
    commentator_id: int | None
    commentator2_id: int | None


def load(session: Session, snapshot: Snapshot, report: Report, ctx: Context) -> None:
    stats = report.collection("matches")
    listings: list[Listing] = []
    for day in snapshot.match_days:
        day_date = date.fromisoformat(day["id"])
        for m in day.get("matches", []):
            wall = parse_cairo_wall_clock(m.get("time"))
            kickoff = cairo_to_utc(day_date, wall) if wall is not None else None
            listings.append(Listing(m, day_date, kickoff, len(listings)))
    stats.source_rows = len(listings)
    report.collection("match_channels").source_rows = sum(len(g.src.get("channelIds") or []) for g in listings)
    report.collection("match_channel_refs").source_rows = sum(_ref_count(g.src) for g in listings)

    _merge_duplicate_listings(listings, report)

    match_ids: dict[str, int] = {}
    for listing in listings:
        if listing.merged_into is None:
            match_ids[listing.legacy_id] = _load_match(session, report, ctx, listing)
            stats.loaded += 1

    # A feed finds its match by (team1, team2, listing date), first listing first, as the old app did.
    for listing in listings:
        survivor = listing.merged_into or listing
        key = (listing.src.get("team1") or "", listing.src.get("team2") or "", listing.match_date.isoformat())
        ctx.matches_by_listing.setdefault(key, match_ids[survivor.legacy_id])

    # Commentators that exist only on matches (README rule 4), created while resolving names.
    from_matches = report.collection("commentators_from_matches")
    from_matches.source_rows = from_matches.loaded = len(ctx.match_only_commentators)

    _load_feeds(session, snapshot, report, ctx)


def _ref_count(src: dict[str, Any]) -> int:
    return (
        len(src.get("importedChannelIds") or [])
        + len(src.get("hiddenChannels") or [])
        + len(src.get("channelCommentators") or {})
    )


def _merge_duplicate_listings(listings: list[Listing], report: Report) -> None:
    """README rule 8: one row per ``ysMatchId``.

    Keep the listing whose ``match_date`` is the Cairo date of its ``kickoff_at`` (a TBD
    listing never qualifies), otherwise the earlier one; ties go to the earlier date, then
    snapshot order.
    """
    by_ys: dict[str, list[Listing]] = {}
    for listing in listings:
        ys_match_id = str(listing.src.get("ysMatchId") or "")
        if ys_match_id:
            by_ys.setdefault(ys_match_id, []).append(listing)

    for group in by_ys.values():
        if len(group) < 2:
            continue
        on_date = [
            g for g in group if g.kickoff_at is not None and g.kickoff_at.astimezone(CAIRO).date() == g.match_date
        ]
        survivor = min(on_date or group, key=lambda g: (g.match_date, g.position))
        for g in group:
            if g is not survivor:
                g.merged_into = survivor
                survivor.extras.append(g)
                report.merged("matches", g.legacy_id, "duplicate_listing", survivor.legacy_id)


def _load_match(session: Session, report: Report, ctx: Context, listing: Listing) -> int:
    src = listing.src
    comp_id = ctx.competitions_by_name_norm.get(ar_normalize(src.get("competition") or ""))
    # Resolve before the row joins the session: these may query, and the autoflush must
    # not insert a half-filled match (a Team that left the identity map is fetched again).
    home_team_id = _resolve_team(session, ctx, report, f"{listing.legacy_id} team1", src.get("team1"), comp_id)
    away_team_id = _resolve_team(session, ctx, report, f"{listing.legacy_id} team2", src.get("team2"), comp_id)
    commentator_id = _resolve_commentator(session, ctx, src.get("commentator"))

    existing = session.execute(select(Match).where(Match.legacy_id == listing.legacy_id)).scalar_one_or_none()
    if existing is None:
        existing = Match(legacy_id=listing.legacy_id)
        session.add(existing)
    existing.sport = "football"
    existing.source = "legacy"  # `src` is empty on every snapshot row (README rule 8)
    existing.match_date = listing.match_date
    existing.kickoff_at = listing.kickoff_at
    existing.time_tbd = listing.kickoff_at is None
    existing.competition_id = comp_id
    existing.competition_name = src.get("competition") or ""
    existing.competition_stage = src.get("competitionStage") or None
    existing.home_team_id = home_team_id
    existing.home_team_name = src.get("team1") or ""
    existing.away_team_id = away_team_id
    existing.away_team_name = src.get("team2") or ""
    existing.stadium = src.get("stadium") or None
    existing.commentator_id = commentator_id
    # `live` was a manual override; clock rows never store a derived state (ck_matches_clock_no_score).
    existing.is_live = False
    existing.status = "scheduled"
    existing.status_source = "clock"
    session.flush()
    match_id: int = existing.id

    for g in [listing, *listing.extras]:
        _load_external_ids(session, g.src, match_id)
    _load_custom_broadcasts(session, ctx, src, match_id)
    _load_match_channels(session, report, ctx, listing, match_id)
    return match_id


def _upsert_external_id(session: Session, source: str, external_id: str, match_id: int, url: str | None) -> None:
    stmt = pg_insert(MatchExternalId).values(source=source, external_id=external_id, match_id=match_id, url=url)
    session.execute(
        stmt.on_conflict_do_update(
            index_elements=["source", "external_id"],
            set_={"match_id": stmt.excluded.match_id, "url": stmt.excluded.url},
        )
    )


def _load_external_ids(session: Session, src: dict[str, Any], match_id: int) -> None:
    # A merged listing's ids move onto the surviving row.
    if src.get("ysMatchId"):
        _upsert_external_id(session, "ysscores", str(src["ysMatchId"]), match_id, None)
    if src.get("lstUrl"):
        _upsert_external_id(session, "livesoccertv", urlsplit(src["lstUrl"]).path, match_id, src["lstUrl"])
    if src.get("seId"):
        _upsert_external_id(session, "sporteventz", str(src["seId"]), match_id, None)


def _load_custom_broadcasts(session: Session, ctx: Context, src: dict[str, Any], match_id: int) -> None:
    # Slot 1: broadcastOn with the match commentator; slot 2: broadcastOn2 with commentator2.
    # The logos (broadcastLogo/broadcastLogo2) are set by rehost-media.
    for slot, label_key, commentator_key in ((1, "broadcastOn", "commentator"), (2, "broadcastOn2", "commentator2")):
        label = src.get(label_key)
        if not label:
            continue
        stmt = pg_insert(MatchCustomBroadcast).values(
            match_id=match_id,
            slot=slot,
            label=label,
            commentator_id=_resolve_commentator(session, ctx, src.get(commentator_key)),
        )
        session.execute(
            stmt.on_conflict_do_update(
                index_elements=["match_id", "slot"],
                set_={"label": stmt.excluded.label, "commentator_id": stmt.excluded.commentator_id},
            )
        )


def _load_match_channels(session: Session, report: Report, ctx: Context, survivor: Listing, match_id: int) -> None:
    """Build one link per channel from the survivor and its merged listings, then upsert.

    Links that collapse onto one channel (a repeated id, merged channel rows, or the same
    channel on a merged listing) become one row: hidden only if every copy was hidden (the
    old app still showed a visible copy), ``ysscores`` only if every copy was imported (an
    importer may only remove its own links), and the first copy's commentators unless it
    had none.
    """
    links = report.collection("match_channels")
    drafts: dict[int, LinkDraft] = {}

    for listing in [survivor, *survivor.extras]:
        src = listing.src
        channel_ids = list(src.get("channelIds") or [])
        imported = set(src.get("importedChannelIds") or [])
        hidden = set(src.get("hiddenChannels") or [])
        commentators: dict[str, Any] = src.get("channelCommentators") or {}
        _check_refs(report, ctx, listing, set(channel_ids))

        for channel_legacy_id in channel_ids:
            ref = f"{listing.legacy_id}/{channel_legacy_id}"
            channel_id = ctx.channels_by_legacy_id.get(channel_legacy_id)
            if channel_id is None:
                report.skipped("match_channels", ref, "channel_not_published")
                continue
            c1, c2 = _link_commentators(session, ctx, commentators.get(channel_legacy_id) or {})
            draft = LinkDraft(
                ref=ref,
                listing=listing.legacy_id,
                source="ysscores" if channel_legacy_id in imported else "legacy",
                is_hidden=channel_legacy_id in hidden,
                commentator_id=c1,
                commentator2_id=c2,
            )
            first = drafts.get(channel_id)
            if first is None:
                drafts[channel_id] = draft
                continue
            reason = "duplicate_listing" if first.listing != listing.legacy_id else "duplicate_carriage"
            report.merged("match_channels", ref, reason, first.ref)
            first.is_hidden = first.is_hidden and draft.is_hidden
            if draft.source != "ysscores":
                first.source = "legacy"
            if first.commentator_id is None:
                first.commentator_id, first.commentator2_id = draft.commentator_id, draft.commentator2_id

    for channel_id, d in drafts.items():
        stmt = pg_insert(MatchChannel).values(
            match_id=match_id,
            channel_id=channel_id,
            source=d.source,
            is_hidden=d.is_hidden,
            commentator_id=d.commentator_id,
            commentator2_id=d.commentator2_id,
        )
        session.execute(
            stmt.on_conflict_do_update(
                index_elements=["match_id", "channel_id"],
                set_={
                    "source": stmt.excluded.source,
                    "is_hidden": stmt.excluded.is_hidden,
                    "commentator_id": stmt.excluded.commentator_id,
                    "commentator2_id": stmt.excluded.commentator2_id,
                },
            )
        )
        links.loaded += 1


def _check_refs(report: Report, ctx: Context, listing: Listing, linked: set[str]) -> None:
    """Count ``importedChannelIds``/``hiddenChannels``/``channelCommentators`` entries; skip and
    log those that point at an unpublished channel or one the listing doesn't link (README rule 3)."""
    src = listing.src
    refs = [
        *(src.get("importedChannelIds") or []),
        *(src.get("hiddenChannels") or []),
        *(src.get("channelCommentators") or {}),
    ]
    stats = report.collection("match_channel_refs")
    for channel_legacy_id in refs:
        ref = f"{listing.legacy_id}/{channel_legacy_id}"
        if channel_legacy_id not in ctx.channels_by_legacy_id:
            report.skipped("match_channel_refs", ref, "channel_not_published")
        elif channel_legacy_id not in linked:
            report.skipped("match_channel_refs", ref, "channel_not_linked")
        else:
            stats.loaded += 1


def _link_commentators(session: Session, ctx: Context, entry: dict[str, Any]) -> tuple[int | None, int | None]:
    """Commentators 1 and 2 for one channel, valid under ck_match_channels_commentators."""
    c1 = _resolve_commentator(session, ctx, entry.get("name"))
    c2 = _resolve_commentator(session, ctx, entry.get("name2"))
    if c1 is None:  # the old admin allowed name2 without name
        c1, c2 = c2, None
    if c2 == c1:
        c2 = None
    return c1, c2


def _resolve_team(
    session: Session, ctx: Context, report: Report, ref: str, name: str | None, competition_id: int | None
) -> int | None:
    """README rule 4: ties between same-named teams are broken by the match competition."""
    if not name:
        return None
    ids = ctx.teams_by_name_norm.get(ar_normalize(name), [])
    if not ids:
        report.warn("team_name_unresolved", ref, name)
        return None
    if len(ids) == 1:
        return ids[0]
    if competition_id is not None:
        for tid in ids:
            team = session.get(Team, tid)
            if team is not None and team.primary_competition_id == competition_id:
                return tid
        linked = (
            session.execute(
                select(TeamCompetition.team_id).where(
                    TeamCompetition.team_id.in_(ids), TeamCompetition.competition_id == competition_id
                )
            )
            .scalars()
            .first()
        )
        if linked is not None:
            return linked
    report.warn("team_name_ambiguous", ref, name)
    return None


def _resolve_commentator(session: Session, ctx: Context, name: str | None) -> int | None:
    """Commentator id by ``name_norm``; names found only on matches are created (README rule 4)."""
    norm = ar_normalize(name)
    if not norm or norm == _NOT_LISTED:
        return None
    if norm in ctx.commentators_by_name_norm:
        return ctx.commentators_by_name_norm[norm]
    existing = session.execute(select(Commentator).where(Commentator.name_norm == norm)).scalar_one_or_none()
    if existing is None:
        existing = Commentator(name=(name or "").strip())
        session.add(existing)
        session.flush()
    ctx.commentators_by_name_norm[norm] = existing.id
    ctx.match_only_commentators.add(norm)
    return existing.id


def _load_feeds(session: Session, snapshot: Snapshot, report: Report, ctx: Context) -> None:
    """Feeds upserted by ``legacy_id``; ``match_id`` is NULL when no listing fits.

    Lines hold tuning only (O3, ck_feeds_no_biss): a line with a BISS key or a card-sharing
    label is dropped and logged by position, never by content.
    """
    stats = report.collection("feeds")
    stats.source_rows = len(snapshot.feeds)
    for src in snapshot.feeds:
        lines: list[str] = []
        for i, raw in enumerate(src.get("freqs") or []):
            line = str(raw).strip()
            if not line:
                continue
            if "biss" in line.lower() or find_card_sharing_label(line) is not None:
                report.warn("feed_line_dropped", src["id"], f"line {i + 1}")
                continue
            lines.append(line)

        team1, team2 = src.get("team1") or "", src.get("team2") or ""
        feed = session.execute(select(Feed).where(Feed.legacy_id == src["id"])).scalar_one_or_none()
        if feed is None:
            feed = Feed(legacy_id=src["id"])
            session.add(feed)
        feed.feed_date = date.fromisoformat(src["date"])
        feed.match_id = ctx.matches_by_listing.get((team1, team2, src["date"]))
        feed.home_team_name = team1
        feed.away_team_name = team2
        feed.lines = lines
        session.flush()
        stats.loaded += 1
