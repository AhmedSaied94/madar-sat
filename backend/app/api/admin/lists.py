"""Small lists for A3 and A4: broadcast presets, always-hidden channel names and sources (contracts/admin-api.md)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Path, Response

from app.api.admin import _docs
from app.api.admin._common import Db, Editor
from app.api.envelope import Envelope, ok
from app.auth.roles import require_editor
from app.schemas import admin as a
from app.schemas import admin_examples as ex
from app.services.admin import lists as service

router = APIRouter(prefix="/admin/api", tags=["lists"], dependencies=[Depends(require_editor)])

_HIDDEN_NOT_FOUND = _docs.not_found("hidden_name_not_found")


@router.get(
    "/broadcast-presets",
    response_model=Envelope[list[a.BroadcastPreset]],
    responses={
        200: {"description": "Presets", **_docs.ok_example("presets_ok", [ex.BROADCAST_PRESET], _docs.LIST_META)},
        **_docs.AUTHED,
    },
    summary="Broadcaster presets for A4's slots (read-only until A11)",
)
async def list_broadcast_presets(session: Db) -> Envelope[list[a.BroadcastPreset]]:
    return ok(await service.broadcast_presets(session))


@router.get(
    "/hidden-channel-names",
    response_model=Envelope[list[a.HiddenChannelName]],
    responses=_docs.AUTHED,
    summary="Channel names hidden from every match page («مخفية دائماً»)",
)
async def list_hidden_channel_names(session: Db) -> Envelope[list[a.HiddenChannelName]]:
    return ok(await service.hidden_names(session))


@router.post(
    "/hidden-channel-names",
    status_code=201,
    response_model=Envelope[a.HiddenChannelName],
    responses={
        201: {"description": "Added; `name` is the normalized form"},
        200: {"model": Envelope[a.HiddenChannelName], "description": "Already hidden"},
        **_docs.AUTHED,
        422: _docs.VALIDATION,
    },
    summary="Hide a channel name everywhere (idempotent; takes no `If-Match`)",
)
async def add_hidden_channel_name(
    body: a.HiddenChannelNameCreate, response: Response, session: Db, admin: Editor
) -> Envelope[a.HiddenChannelName]:
    name, created = await service.add_hidden_name(session, admin, body.name)
    await session.commit()
    response.status_code = 201 if created else 200
    return ok(a.HiddenChannelName(name=name))


@router.delete(
    "/hidden-channel-names/{name}",
    response_model=Envelope[None],
    responses={**_docs.AUTHED, 404: _HIDDEN_NOT_FOUND},
    summary="Show a channel name again (the name is URL-encoded)",
)
async def remove_hidden_channel_name(
    name: Annotated[str, Path(min_length=1, max_length=120)], session: Db, admin: Editor
) -> Envelope[None]:
    await service.remove_hidden_name(session, admin, name)
    await session.commit()
    return ok(None)


@router.get(
    "/sources",
    response_model=Envelope[list[a.SourceItem]],
    responses=_docs.AUTHED,
    summary="Sources, for A3's source filter (read-only until A13)",
)
async def list_sources(session: Db) -> Envelope[list[a.SourceItem]]:
    return ok(await service.sources(session))
