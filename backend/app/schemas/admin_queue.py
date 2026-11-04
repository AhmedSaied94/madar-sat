"""Admin shapes added on D5: A13's unresolved-names queue and A9's rights holders (005 admin-api)."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas import admin_examples as ex
from app.schemas.admin import Etag, Id, Int32, Name120, Text80, _Body
from app.schemas.public import Access, Beam, Polarization

MAX_LIST_ITEMS = 200
MAX_CARRIAGE_ITEMS = 32

# --- Unresolved names (A13) -----------------------------------------------------------------------

UnresolvedKind = Literal["team", "competition", "channel"]
UnresolvedState = Literal["open", "mapped", "created", "ignored"]


class UnresolvedContext(BaseModel):
    """Where the source last showed the name. Written by the importers, so each part may be absent."""

    match_id: int | None = None
    home: str | None = None
    away: str | None = None
    competition: str | None = None
    kickoff_at: datetime | None = None


class UnresolvedSuggestion(BaseModel):
    id: int
    name: str
    detail: str | None
    confidence: Annotated[int, Field(ge=0, le=100)]
    exact: bool


class UnresolvedNameRow(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.UNRESOLVED_NAME]})

    id: int
    source: str
    kind: UnresolvedKind
    name: str
    context: UnresolvedContext
    seen_count: Int32
    last_seen_at: datetime
    state: UnresolvedState
    etag: Etag
    suggestions: list[UnresolvedSuggestion]


class UnresolvedMap(_Body):
    model_config = ConfigDict(extra="forbid", json_schema_extra={"examples": [ex.UNRESOLVED_MAP]})

    target_id: Id
    scope_to_competition: bool = False
    created: bool = False


# --- Rights holders (A9) --------------------------------------------------------------------------


class RightsHolderFrequencyInput(_Body):
    frequency_mhz: int
    polarization: Polarization
    symbol_rate: int
    is_primary: bool = False


class RightsHolderCarriageInput(_Body):
    access: Access
    beam: Beam | None = None
    package: Text80 | None = None
    satellite_ids: Annotated[list[Id], Field(max_length=MAX_CARRIAGE_ITEMS)] = []
    frequencies: Annotated[list[RightsHolderFrequencyInput], Field(max_length=MAX_CARRIAGE_ITEMS)] = []


class RightsHolderCreate(_Body):
    model_config = ConfigDict(extra="forbid", json_schema_extra={"examples": [ex.RIGHTS_HOLDER_BODY]})

    name: Name120
    logo_asset_id: Id | None = None
    competition_ids: Annotated[list[Id], Field(max_length=MAX_LIST_ITEMS)] = []
    carriages: Annotated[list[RightsHolderCarriageInput], Field(max_length=MAX_CARRIAGE_ITEMS)] = []


class RightsHolderPatch(_Body):
    """An omitted field stays as it is; ``competition_ids`` and ``carriages`` replace the whole list."""

    model_config = ConfigDict(extra="forbid", json_schema_extra={"examples": [ex.RIGHTS_HOLDER_BODY]})

    name: Name120 | None = None
    logo_asset_id: Id | None = None
    competition_ids: Annotated[list[Id], Field(max_length=MAX_LIST_ITEMS)] | None = None
    carriages: Annotated[list[RightsHolderCarriageInput], Field(max_length=MAX_CARRIAGE_ITEMS)] | None = None


class AdminRightsHolderFrequency(BaseModel):
    frequency_mhz: int
    polarization: Polarization
    symbol_rate: int
    is_primary: bool


class AdminRightsHolderCarriage(BaseModel):
    access: Access
    beam: Beam | None
    package: str | None
    satellite_ids: list[int]
    frequencies: list[AdminRightsHolderFrequency]


class AdminRightsHolder(BaseModel):
    """The full editor shape."""

    model_config = ConfigDict(json_schema_extra={"examples": [ex.RIGHTS_HOLDER]})

    id: int
    name: str
    logo_asset_id: int | None
    logo: str | None
    sort_order: int | None
    competition_ids: list[int]
    carriages: list[AdminRightsHolderCarriage]
    etag: Etag


class AdminRightsHolderRow(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.RIGHTS_HOLDER_ROW]})

    id: int
    name: str
    logo: str | None
    sort_order: int | None
    competitions: list[str]
    satellites: list[str]
    etag: Etag
