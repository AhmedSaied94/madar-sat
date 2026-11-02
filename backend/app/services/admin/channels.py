"""Channels: read, create, update and (soft) delete."""

from __future__ import annotations

from collections.abc import Mapping
from datetime import datetime
from typing import Any

from sqlalchemy import ColumnElement, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import EntityNotFound
from app.auth.roles import AuthedAdmin
from app.db.models import Channel, HiddenChannelName, Satellite
from app.domain.lockable import CHANNEL_LOCKABLE
from app.schemas import admin as a
from app.schemas.public import Access, Beam, Category, Frequency, Kind, Polarization
from app.services.admin import refs, versions, writer
from app.services.admin.common import asset_urls, sent, tuning_errors, url_of

ENTITY = "channels"
NOT_FOUND = "channel_not_found"
PLAIN_COLUMNS = (
    "name",
    "display_name",
    "logo_asset_id",
    "category",
    "country",
    "satellite_id",
    "frequency_note",
    "access",
    "provider",
    "package",
    "beam",
    "show_in_match",
    "sort_order",
)
ENUM_COLUMNS = ("category", "access", "beam")


def hidden_by_name() -> ColumnElement[bool]:
    """«مخفية دائماً»: the channel's name or display name is in ``hidden_channel_names``."""
    hidden = select(HiddenChannelName.name)
    return or_(
        Channel.name_norm.in_(hidden),
        func.ar_normalize(func.coalesce(Channel.display_name, "")).in_(hidden),
    )


async def get(session: AsyncSession, channel_id: int) -> Channel:
    """A live channel. A soft-deleted one is gone as far as the admin API is concerned."""
    channel = await session.get(Channel, channel_id)
    if channel is None or channel.deleted_at is not None:
        raise EntityNotFound(NOT_FOUND)
    return channel


def frequency_of(channel: Channel) -> Frequency | None:
    if channel.frequency_mhz is None or channel.polarization is None or channel.symbol_rate is None:
        return None
    return Frequency(mhz=channel.frequency_mhz, pol=Polarization(channel.polarization), sr=channel.symbol_rate)


def _enum(enum: Any, value: str | None) -> Any:
    return enum(value) if value is not None else None


def item_fields(channel: Channel, hidden: bool, logo: str | None) -> dict[str, Any]:
    return {
        "id": channel.id,
        "kind": Kind(channel.kind),
        "name": channel.name,
        "display_name": channel.display_name,
        "logo_asset_id": channel.logo_asset_id,
        "logo": logo,
        "category": _enum(Category, channel.category),
        "country": channel.country,
        "satellite_id": channel.satellite_id,
        "frequency": frequency_of(channel),
        "frequency_note": channel.frequency_note,
        "access": _enum(Access, channel.access),
        "provider": channel.provider,
        "package": channel.package,
        "beam": _enum(Beam, channel.beam),
        "show_in_match": channel.show_in_match,
        "sort_order": channel.sort_order,
        "hidden_by_name": hidden,
        "placeholder_source": channel.placeholder_source,
    }


def to_item(channel: Channel, hidden: bool, logo: str | None) -> a.ChannelItem:
    return a.ChannelItem(**item_fields(channel, hidden, logo))


async def is_hidden(session: AsyncSession, channel: Channel) -> bool:
    return bool(await session.scalar(select(hidden_by_name()).where(Channel.id == channel.id)))


async def view(session: AsyncSession, channel: Channel) -> a.AdminChannel:
    urls = await asset_urls(session, [channel.logo_asset_id])
    fields = item_fields(channel, await is_hidden(session, channel), url_of(urls, channel.logo_asset_id))
    return a.AdminChannel(**fields, locked_fields=sorted(channel.locked_fields or []))


async def version(session: AsyncSession, channel: Channel) -> str:
    return versions.row_version(channel)


def kind_errors(kind: str, state: Mapping[str, Any]) -> list[dict[str, Any]]:
    """``ck_channels_kind_fields``: which fields a channel of this ``kind`` has to have, and may not have."""
    errors: list[dict[str, Any]] = []

    def need(field: str) -> None:
        if state.get(field) is None:
            errors.append(refs.field_error([field], "required"))

    def forbid(field: str) -> None:
        if state.get(field) is not None:
            errors.append(refs.field_error([field], "not_allowed"))

    if kind in ("satellite", "terrestrial"):
        need("satellite_id")
        need("access")
    if kind == "terrestrial":
        forbid("frequency_mhz")
    if kind == "platform":
        for field in ("satellite_id", "frequency_mhz", "frequency_note", "beam"):
            forbid(field)
    return errors


async def _check(
    session: AsyncSession,
    kind: str,
    state: Mapping[str, Any],
    touched: Mapping[str, Any],
    needs_tuning: bool = False,
) -> None:
    errors = kind_errors(kind, state)
    # A channel moved onto a satellite (an importer's platform placeholder, A-R1-5) has to say where
    # to tune: a frequency, or the note the base schema allows in its place. Without either it would
    # reach the app as a satellite channel with nothing to dial.
    if needs_tuning and state.get("frequency_mhz") is None and state.get("frequency_note") is None:
        errors.append(refs.field_error(["frequency"], "required"))
    if "frequency" in touched:
        errors += tuning_errors(touched["frequency"], ["frequency"])
    errors += await refs.missing_refs(session, [(Satellite, [touched.get("satellite_id")], ["satellite_id"])])
    errors += await refs.missing_assets(session, [(touched.get("logo_asset_id"), refs.IMAGE_KINDS, ["logo_asset_id"])])
    refs.raise_if_any(errors)


def _set_frequency(channel: Channel, frequency: Frequency | None) -> None:
    channel.frequency_mhz = frequency.mhz if frequency else None
    channel.polarization = frequency.pol.value if frequency else None
    channel.symbol_rate = frequency.sr if frequency else None


def _value(value: Any) -> Any:
    return value.value if hasattr(value, "value") else value


async def create(session: AsyncSession, admin: AuthedAdmin, body: a.ChannelCreate) -> Channel:
    values = {column: _value(getattr(body, column)) for column in PLAIN_COLUMNS}
    state = {**values, "frequency_mhz": body.frequency.mhz if body.frequency else None}
    await _check(session, body.kind.value, state, {**values, "frequency": body.frequency})

    channel = Channel(kind=body.kind.value, locked_fields=[], **values)
    _set_frequency(channel, body.frequency)
    session.add(channel)
    await writer.save_create(session, admin, entity=ENTITY, row=channel, datasets=writer.CHANNEL_CHANGED)
    return channel


async def update(
    session: AsyncSession,
    admin: AuthedAdmin,
    channel_id: int,
    body: a.ChannelPatch,
    if_match: str | None,
    now: datetime,
) -> Channel:
    channel = await writer.lock_and_check(session, Channel, channel_id, NOT_FOUND, ENTITY, if_match)
    if channel.deleted_at is not None:
        raise EntityNotFound(NOT_FOUND)
    changes = sent(body)
    if changes.get("name", "") is None:
        refs.raise_if_any([refs.field_error(["name"], "null_not_allowed")])
    for column in ("kind", "show_in_match"):
        if column in changes and changes[column] is None:
            refs.raise_if_any([refs.field_error([column], "null_not_allowed")])

    before = versions.row_state(channel)
    became_satellite = "kind" in changes and changes["kind"].value == "satellite" and channel.kind != "satellite"
    if "kind" in changes:
        channel.kind = _value(changes["kind"])
    for column in PLAIN_COLUMNS:
        if column in changes:
            setattr(channel, column, _value(changes[column]))
    if "frequency" in changes:
        _set_frequency(channel, changes["frequency"])
    # A placeholder an editor puts on match pages becomes a normal channel (research R13, R18);
    # the same audit entry records both fields.
    if changes.get("show_in_match") is True and channel.placeholder_source is not None:
        channel.placeholder_source = None

    state = {key: getattr(channel, key) for key in (*PLAIN_COLUMNS, "frequency_mhz")}
    await _check(session, channel.kind, state, changes, needs_tuning=became_satellite)
    await writer.save_update(
        session,
        admin,
        entity=ENTITY,
        row=channel,
        before=before,
        datasets=writer.CHANNEL_CHANGED,
        now=now,
        lockable=CHANNEL_LOCKABLE,
    )
    return channel


async def remove(
    session: AsyncSession, admin: AuthedAdmin, channel_id: int, if_match: str | None, now: datetime
) -> None:
    """Soft delete: the row stays for the links and the ``/v1/channels/sync`` tombstone."""
    channel = await writer.lock_and_check(session, Channel, channel_id, NOT_FOUND, ENTITY, if_match)
    if channel.deleted_at is not None:
        raise EntityNotFound(NOT_FOUND)
    await writer.save_delete(
        session, admin, entity=ENTITY, row=channel, datasets=writer.CHANNEL_CHANGED, now=now, soft=True
    )
