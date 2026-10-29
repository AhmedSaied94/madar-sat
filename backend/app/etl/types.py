"""Snapshot data container and cross-step lookup context."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class Snapshot:
    satellites: list[dict[str, Any]]
    channels: list[dict[str, Any]]
    competitions: list[dict[str, Any]]
    teams: list[dict[str, Any]]
    rights: list[dict[str, Any]]
    settings: list[dict[str, Any]]  # firestore settings docs (authoritative for ordering)
    match_days: list[dict[str, Any]]
    team_dict: list[dict[str, Any]]
    feeds: list[dict[str, Any]]

    def setting(self, doc_id: str) -> dict[str, Any] | None:
        for doc in self.settings:
            if doc.get("id") == doc_id:
                return doc
        return None

    def order(self, doc_id: str) -> list[str]:
        doc = self.setting(doc_id)
        return list(doc.get("order", [])) if doc else []


@dataclass
class Context:
    """Cross-step lookups: source key → database id / row."""

    satellites_by_legacy_id: dict[str, int] = field(default_factory=dict)
    satellites_by_name_en: dict[str, int] = field(default_factory=dict)  # raw name_en -> id
    competitions_by_legacy_id: dict[str, int] = field(default_factory=dict)
    competitions_by_name_norm: dict[str, int] = field(default_factory=dict)
    teams_by_legacy_id: dict[str, int] = field(default_factory=dict)
    teams_by_name_norm: dict[str, list[int]] = field(default_factory=dict)
    commentators_by_name_norm: dict[str, int] = field(default_factory=dict)
    match_only_commentators: set[str] = field(default_factory=set)  # name_norms not in settings/commentators
    channels_by_legacy_id: dict[str, int] = field(default_factory=dict)
    # (team1, team2, listing date) -> surviving match id, the key the old app used to find a feed's match.
    matches_by_listing: dict[tuple[str, str, str], int] = field(default_factory=dict)


def read_snapshot(snapshot_dir: str) -> Snapshot:
    root = Path(snapshot_dir)
    hosting = root / "hosting"
    firestore = root / "firestore"

    def _load(base: Path, name: str) -> Any:
        p = base / f"{name}.json"
        if not p.exists():
            return None
        return json.loads(p.read_text(encoding="utf-8"))

    return Snapshot(
        satellites=_load(hosting, "satellites") or [],
        channels=_load(hosting, "channels") or [],
        competitions=_load(hosting, "competitions") or [],
        teams=_load(hosting, "teams") or [],
        rights=_load(hosting, "rights") or [],
        settings=_load(firestore, "settings") or [],
        match_days=_load(firestore, "matchDays") or [],
        team_dict=_load(firestore, "teamDict") or [],
        feeds=_load(firestore, "feeds") or [],
    )
