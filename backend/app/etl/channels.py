"""Channels and rights holders load (README rules 3, 5, 9, 10)."""

from __future__ import annotations

from typing import Any

from sqlalchemy import and_, not_, select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session

from app.db.models import (
    Channel,
    RightsHolder,
    RightsHolderCarriage,
    RightsHolderCarriageSatellite,
    RightsHolderCompetition,
    RightsHolderFrequency,
)
from app.domain.arabic import ar_normalize
from app.domain.frequency import Frequency, parse_frequency, unique_frequencies
from app.etl.checks import strip_card_sharing_labels
from app.etl.report import Report
from app.etl.types import Context, Snapshot


def _map_beam(bundle: str | None) -> str | None:
    if bundle == "عامة":
        return "wide"
    if bundle == "ضيقة":
        return "narrow"
    return None


def _map_access(kind: str, free: bool) -> str | None:
    if kind == "platform":
        return "free" if free else None
    return "free" if free else "encrypted"


def _channel_kind(satellite_en: str | None) -> str:
    if not satellite_en:
        return "platform"
    if satellite_en == "DVB T2":
        return "terrestrial"
    return "satellite"


def _frequency(
    report: Report, ref: str, kind: str, value: str | None
) -> tuple[int | None, str | None, int | None, str | None]:
    """Return (mhz, pol, sr, note). Anything that isn't a DVB-S tuning is kept as a note."""
    if not value:
        return None, None, None, None
    # A terrestrial row never has a DVB-S tuning (ck_channels_kind_fields): "UHF 32" is a note.
    freq, reason = parse_frequency(value) if kind == "satellite" else (None, "unparseable")
    if freq is not None:
        return freq.mhz, freq.pol, freq.sr, None
    if reason == "out_of_domain":
        report.checks["frequencies_out_of_domain"] += 1
    report.warn("frequency_unparseable", ref, value)
    return None, None, None, value


def _order_index(report: Report, collection: str, order: list[str], known: set[str], reason: str) -> dict[str, int]:
    """Index of each id in a settings order list; ids with no row are skipped and logged (README rule 3)."""
    stats = report.collection(collection)
    stats.source_rows = len(order)
    index: dict[str, int] = {}
    for i, legacy_id in enumerate(order):
        if legacy_id not in known:
            report.skipped(collection, legacy_id, reason)
            continue
        index.setdefault(legacy_id, i)
        stats.loaded += 1
    return index


def load(session: Session, snapshot: Snapshot, report: Report, ctx: Context) -> None:
    _load_channels(session, snapshot, report, ctx)
    _load_rights_holders(session, snapshot, report, ctx)


def _load_channels(session: Session, snapshot: Snapshot, report: Report, ctx: Context) -> None:
    stats = report.collection("channels")
    stats.source_rows = len(snapshot.channels)
    known = {c["id"] for c in snapshot.channels}
    # hosting lags Firestore: channelOrder lists ids that aren't published (README rule 2).
    order = _order_index(report, "channel_order", snapshot.order("channelOrder"), known, "channel_not_published")

    # First pass: compute each channel's fields and dedupe key. `encryption`, `satellite`
    # (Arabic name) and `order` are never read (README rule 9).
    rows: list[dict[str, Any]] = []
    kinds: dict[str, int] = {}
    for src in snapshot.channels:
        satellite_en = src.get("satelliteEn") or ""
        kind = _channel_kind(satellite_en)
        kinds[kind] = kinds.get(kind, 0) + 1
        # A card-sharing label is never stored (FR-005): drop it from the names, before the
        # dedupe key, and skip a channel whose name is nothing but a label.
        name = strip_card_sharing_labels(src["name"])
        if name is None:
            report.skipped("channels", src["id"], "name_is_card_sharing_label")
            continue
        display_name = strip_card_sharing_labels(src.get("displayName")) or None
        renames = (("name", src["name"], name), ("displayName", src.get("displayName"), display_name))
        for field, before, after in renames:
            if before and after != before:
                report.warn("card_sharing_label_stripped", src["id"], f"{field}: {before} → {after or ''}")
        # Resolve against the raw name: " Eutel 16.0E" (Africa) is not "Eutel 16.0E".
        satellite_id = ctx.satellites_by_name_en.get(satellite_en) if satellite_en else None

        if kind == "platform":
            # A platform row keeps no tuning; the one "frequency" («كازاخستان») is dropped.
            mhz = pol = sr = note = None
        else:
            mhz, pol, sr, note = _frequency(report, src["id"], kind, src.get("frequency"))

        key: Any
        if kind == "satellite" and mhz is not None:  # channels_carriage_key
            key = ("satellite", ar_normalize(name), satellite_id, mhz, pol, sr)
        elif kind == "platform":  # channels_platform_key
            key = ("platform", ar_normalize(name), src.get("country") or None)
        else:
            key = ("unique", src["id"])

        rows.append(
            {
                "src": src,
                "name": name,
                "display_name": display_name,
                "kind": kind,
                "satellite_id": satellite_id,
                "access": _map_access(kind, bool(src.get("free"))),
                "beam": _map_beam(src.get("bundle")) if kind != "platform" else None,
                "show_in_match": bool(src.get("showInMatch")),
                "sort_order": order.get(src["id"]),
                "mhz": mhz,
                "pol": pol,
                "sr": sr,
                "note": note,
                "key": key,
            }
        )
    report.kinds["channels"] = kinds

    # Group by dedupe key; keep the row with the lowest channelOrder index.
    groups: dict[Any, list[dict[str, Any]]] = {}
    for r in rows:
        groups.setdefault(r["key"], []).append(r)

    for group in groups.values():
        group.sort(key=lambda r: (r["sort_order"] is None, r["sort_order"] or 0))
        r = group[0]
        src = r["src"]

        existing = session.execute(select(Channel).where(Channel.legacy_id == src["id"])).scalar_one_or_none()
        if existing is None:
            existing = Channel(legacy_id=src["id"])
            session.add(existing)
        existing.kind = r["kind"]
        existing.name = r["name"]
        existing.display_name = r["display_name"]
        existing.category = src.get("category") or None
        existing.country = (src.get("country") or None) if r["kind"] == "platform" else None
        existing.satellite_id = r["satellite_id"]
        existing.frequency_mhz = r["mhz"]
        existing.polarization = r["pol"]
        existing.symbol_rate = r["sr"]
        existing.frequency_note = r["note"]
        existing.access = r["access"]
        existing.provider = None
        existing.package = None
        existing.beam = r["beam"]
        existing.show_in_match = r["show_in_match"]
        existing.sort_order = r["sort_order"]
        session.flush()
        stats.loaded += 1
        ctx.channels_by_legacy_id[src["id"]] = existing.id

        # Merged rows' match links resolve to the survivor (README rule 9).
        for merged in group[1:]:
            ctx.channels_by_legacy_id[merged["src"]["id"]] = existing.id
            report.merged("channels", merged["src"]["id"], "duplicate_carriage", src["id"])


def _load_rights_holders(session: Session, snapshot: Snapshot, report: Report, ctx: Context) -> None:
    stats = report.collection("rights_holders")
    stats.source_rows = len(snapshot.rights)
    known = {r["id"] for r in snapshot.rights}
    order = _order_index(report, "rights_order", snapshot.order("rightsOrder"), known, "rights_order_unknown_id")

    for src in snapshot.rights:
        existing = session.execute(select(RightsHolder).where(RightsHolder.legacy_id == src["id"])).scalar_one_or_none()
        if existing is None:
            existing = RightsHolder(legacy_id=src["id"])
            session.add(existing)
        existing.name = src.get("channel", "")
        existing.sort_order = order.get(src["id"])
        session.flush()
        stats.loaded += 1

        # Competitions by name.
        for comp_name in src.get("competitions") or []:
            comp_id = ctx.competitions_by_name_norm.get(ar_normalize(comp_name))
            if comp_id is None:
                report.warn("rights_competition_unresolved", src["id"], comp_name)
                continue
            session.execute(
                pg_insert(RightsHolderCompetition)
                .values(rights_holder_id=existing.id, competition_id=comp_id)
                .on_conflict_do_nothing()
            )

        carriage_satellites: set[str] = set()
        for position, carriage_src in enumerate(src.get("frequencies") or []):
            carriage_satellites |= _load_carriage(session, report, ctx, src["id"], existing.id, position, carriage_src)

        # rights.satellite[] is dropped: it should be the union of the carriages' satellites.
        listed = set(src.get("satellite") or [])
        if listed != carriage_satellites:
            report.warn(
                "rights_satellites_mismatch",
                src["id"],
                f"satellite[]={sorted(listed)} carriages={sorted(carriage_satellites)}",
            )


def _load_carriage(
    session: Session,
    report: Report,
    ctx: Context,
    rights_legacy_id: str,
    rights_holder_id: int,
    position: int,
    carriage_src: dict[str, Any],
) -> set[str]:
    """Upsert one rights carriage (by holder and position) with its satellites and frequencies.

    Returns the carriage's raw satellite names. `encryption` is never read (README rule 10).
    """
    stmt = pg_insert(RightsHolderCarriage).values(
        rights_holder_id=rights_holder_id,
        position=position,
        access="free" if carriage_src.get("free") else "encrypted",
        beam=_map_beam(carriage_src.get("bundle")),
    )
    carriage_id = session.execute(
        stmt.on_conflict_do_update(
            index_elements=["rights_holder_id", "position"],
            set_={"access": stmt.excluded.access, "beam": stmt.excluded.beam},
        ).returning(RightsHolderCarriage.id)
    ).scalar_one()

    sat_ref = carriage_src.get("satellite")
    sat_names: list[str] = sat_ref if isinstance(sat_ref, list) else ([sat_ref] if sat_ref else [])
    for name in sat_names:
        sat_id = ctx.satellites_by_name_en.get(name)
        if sat_id is None:
            report.warn("rights_satellite_unresolved", rights_legacy_id, name)
            continue
        session.execute(
            pg_insert(RightsHolderCarriageSatellite)
            .values(carriage_id=carriage_id, satellite_id=sat_id)
            .on_conflict_do_nothing()
        )

    # frequencies[].frequency is the primary one; frequencies[].frequencies[] may repeat it
    # or list a tuning twice (README rule 5), so dedupe in first-seen order.
    primary_value = carriage_src.get("frequency")
    primary: Frequency | None = None
    parsed: list[Frequency] = []
    for i, value in enumerate(([primary_value] if primary_value else []) + list(carriage_src.get("frequencies") or [])):
        freq, _reason = parse_frequency(value)
        if freq is None:
            report.warn("frequency_unparseable", rights_legacy_id, value)
            continue
        if i == 0 and primary_value:
            primary = freq
        parsed.append(freq)

    # At most one primary per carriage (rights_holder_frequencies_one_primary): clear any
    # other primary before upserting, in case a refreshed snapshot moved it.
    clear = update(RightsHolderFrequency).where(
        RightsHolderFrequency.carriage_id == carriage_id, RightsHolderFrequency.is_primary.is_(True)
    )
    if primary is not None:
        clear = clear.where(
            not_(
                and_(
                    RightsHolderFrequency.frequency_mhz == primary.mhz,
                    RightsHolderFrequency.polarization == primary.pol,
                    RightsHolderFrequency.symbol_rate == primary.sr,
                )
            )
        )
    session.execute(clear.values(is_primary=False))

    for freq in unique_frequencies(parsed):
        fstmt = pg_insert(RightsHolderFrequency).values(
            carriage_id=carriage_id,
            frequency_mhz=freq.mhz,
            polarization=freq.pol,
            symbol_rate=freq.sr,
            is_primary=freq == primary,
        )
        session.execute(
            fstmt.on_conflict_do_update(
                index_elements=["carriage_id", "frequency_mhz", "polarization", "symbol_rate"],
                set_={"is_primary": fstmt.excluded.is_primary},
            )
        )
    return set(sat_names)
