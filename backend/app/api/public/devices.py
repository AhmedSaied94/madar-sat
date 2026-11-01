"""``/v1/devices`` and ``/v1/devices/me*`` (contracts/public-devices.md).

The four device routes: register (no auth), update, replace the follow set, and delete. Every
response is ``Cache-Control: no-store`` and none ever carries an ``ETag``; the token is returned
exactly once, by registration.
"""

from __future__ import annotations

from datetime import datetime
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_now
from app.api.envelope import Envelope, ok
from app.db.session import get_session
from app.devices import follows as follows_service
from app.devices import service
from app.devices.auth import DeviceDep, device_auth
from app.schemas import public as s

router = APIRouter(prefix="/v1/devices", tags=["devices"])

SessionDb = Annotated[AsyncSession, Depends(get_session)]
Now = Annotated[datetime, Depends(get_now)]

NO_STORE = "no-store"
UNAUTHENTICATED: dict[int | str, Any] = {
    401: {"description": "`401 unauthenticated` (missing, malformed or unknown token)"}
}
VALIDATION: dict[int | str, Any] = {
    422: {"description": "`422 validation_error`, `unknown_satellite` or `unknown_follow_target`"}
}
RATE_LIMITED: dict[int | str, Any] = {
    429: {"description": "`429 rate_limited` with `Retry-After` and `meta.retry_after_s`"}
}


def _no_store(response: Response) -> None:
    response.headers["Cache-Control"] = NO_STORE


@router.post(
    "",
    status_code=201,
    response_model=Envelope[s.DeviceRegistered],
    responses={
        201: {
            "description": "Registered; the token is returned once",
            "content": {
                "application/json": {
                    "examples": {
                        "device_registered": {
                            "value": {
                                "success": True,
                                "data": {
                                    "device_id": 812,
                                    "device_token": "Q2hhbmdlTWUtNDMtY2hhcnMtYmFzZTY0dXJsLXRva2Vu",
                                },
                                "error": None,
                                "meta": {"generated_at": "2026-11-01T08:00:00Z"},
                            }
                        }
                    }
                }
            },
        },
        **VALIDATION,
        **RATE_LIMITED,
    },
    summary="Register an install id, or rotate its token",
)
async def register_device(
    body: s.DeviceRegister, response: Response, session: SessionDb, now: Now
) -> Envelope[s.DeviceRegistered]:
    device, token = await service.register(session, body, now)
    await session.commit()
    response.headers["Cache-Control"] = NO_STORE
    return ok(s.DeviceRegistered(device_id=device.id, device_token=token))


@router.put(
    "/me",
    response_model=Envelope[s.Device],
    responses={200: {"description": "The stored device"}, **UNAUTHENTICATED, **VALIDATION, **RATE_LIMITED},
    summary="Update this device's push token, app version, locale, time zone, satellites or prefs",
    dependencies=[Depends(_no_store), Depends(device_auth)],
)
async def update_device(
    body: s.DeviceUpdate, response: Response, device: DeviceDep, session: SessionDb
) -> Envelope[s.Device]:
    await service.update(session, device, body)
    await session.commit()
    response.headers["Cache-Control"] = NO_STORE
    return ok(service.view(device))


@router.put(
    "/me/follows",
    response_model=Envelope[s.FollowSet],
    responses={200: {"description": "The stored set"}, **UNAUTHENTICATED, **VALIDATION, **RATE_LIMITED},
    summary="Replace this device's whole follow set (atomic; ≤ 500 ids)",
    dependencies=[Depends(_no_store), Depends(device_auth)],
)
async def replace_follows(
    body: s.FollowSet, response: Response, device: DeviceDep, session: SessionDb
) -> Envelope[s.FollowSet]:
    stored = await follows_service.replace(session, device.id, body)
    await session.commit()
    response.headers["Cache-Control"] = NO_STORE
    return ok(stored)


@router.delete(
    "/me",
    status_code=204,
    responses={**UNAUTHENTICATED, **RATE_LIMITED},
    summary="Delete this device and its follows",
    dependencies=[Depends(_no_store), Depends(device_auth)],
)
async def delete_device(device: DeviceDep, session: SessionDb) -> Response:
    await service.remove(session, device)
    await session.commit()
    return Response(status_code=204, headers={"Cache-Control": NO_STORE})
