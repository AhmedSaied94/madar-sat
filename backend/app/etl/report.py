"""The snapshot load report (contracts/load-report.md)."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


@dataclass
class CollectionStats:
    source_rows: int = 0
    loaded: int = 0
    merged: int = 0
    skipped: int = 0
    skip_reasons: dict[str, int] = field(default_factory=dict)

    def skip(self, reason: str) -> None:
        self.skipped += 1
        self.skip_reasons[reason] = self.skip_reasons.get(reason, 0) + 1

    def reconciles(self) -> bool:
        return (
            self.source_rows == self.loaded + self.merged + self.skipped
            and sum(self.skip_reasons.values()) == self.skipped
        )

    def as_dict(self) -> dict[str, Any]:
        return {
            "source_rows": self.source_rows,
            "loaded": self.loaded,
            "merged": self.merged,
            "skipped": self.skipped,
            "skip_reasons": self.skip_reasons,
        }


def media_reconciles(media: dict[str, Any]) -> bool:
    """``urls_total = already_hosted + rehosted + deduplicated + failed`` (contract "media").

    Failed URLs don't break reconciliation: each one is counted under a reason, logged in
    the details file and leaves its column NULL.
    """
    total: int = media["urls_total"]
    failed: int = media["failed"]
    parts: int = media["already_hosted"] + media["rehosted"] + media["deduplicated"] + failed
    return total == parts and sum(media["fail_reasons"].values()) == failed and sum(media["hosts"].values()) == total


class Report:
    def __init__(self, command: str, snapshot_dir: str) -> None:
        self.command = command
        self.snapshot_dir = snapshot_dir
        self.started_at = datetime.now(UTC)
        self.collections: dict[str, CollectionStats] = {}
        self.warnings: list[dict[str, str]] = []
        self.details: list[dict[str, Any]] = []
        self.checks: dict[str, int] = {"card_sharing_labels_found": 0, "frequencies_out_of_domain": 0}
        self.media: dict[str, Any] | None = None
        self.kinds: dict[str, dict[str, int]] = {}

    def collection(self, name: str) -> CollectionStats:
        return self.collections.setdefault(name, CollectionStats())

    def warn(self, code: str, ref: str, value: str) -> None:
        self.warnings.append({"code": code, "ref": ref, "value": value})

    def detail(self, collection: str, legacy_id: str | None, action: str, reason: str, into: Any = None) -> None:
        line: dict[str, Any] = {"collection": collection, "legacy_id": legacy_id, "action": action, "reason": reason}
        if into is not None:
            line["into"] = into
        self.details.append(line)

    def skipped(self, collection: str, legacy_id: str, reason: str) -> None:
        """Count a skip and write its details line, so every count traces back to rows."""
        self.collection(collection).skip(reason)
        self.detail(collection, legacy_id, "skip", reason)

    def merged(self, collection: str, legacy_id: str, reason: str, into: str) -> None:
        self.collection(collection).merged += 1
        self.detail(collection, legacy_id, "merge", reason, into)

    @property
    def reconciled(self) -> bool:
        checks_ok = all(v == 0 for v in self.checks.values())
        collections_ok = all(c.reconciles() for c in self.collections.values())
        if self.media is not None:  # rehost-media: no collections, the media block reconciles
            return checks_ok and collections_ok and media_reconciles(self.media)
        return bool(self.collections) and checks_ok and collections_ok

    def as_dict(self, finished_at: datetime, details_file: str) -> dict[str, Any]:
        return {
            "command": self.command,
            "snapshot_dir": self.snapshot_dir,
            "started_at": _iso(self.started_at),
            "finished_at": _iso(finished_at),
            "reconciled": self.reconciled,
            "collections": {k: v.as_dict() for k, v in self.collections.items()},
            "kinds": self.kinds,
            "warnings": self.warnings,
            "details_file": details_file,
            "checks": self.checks,
            "media": self.media,
        }

    def write(self, report_dir: str) -> tuple[Path, Path]:
        """Write ``load-report-<UTC timestamp>.json`` and its details JSONL; return both paths."""
        finished = datetime.now(UTC)
        ts = finished.strftime("%Y%m%dT%H%M%SZ")
        root = Path(report_dir)
        root.mkdir(parents=True, exist_ok=True)
        details_path = root / f"load-report-{ts}.details.jsonl"
        with details_path.open("w", encoding="utf-8") as fh:
            for line in self.details:
                fh.write(json.dumps(line, ensure_ascii=False, sort_keys=True) + "\n")
        json_path = root / f"load-report-{ts}.json"
        data = self.as_dict(finished, details_path.name)
        json_path.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return json_path, details_path

    def summary(self) -> list[str]:
        """The short human-readable summary the CLI prints."""
        lines = [f"{self.command}: reconciled={self.reconciled}"]
        for name, c in self.collections.items():
            reasons = ", ".join(f"{k}={v}" for k, v in sorted(c.skip_reasons.items()))
            lines.append(
                f"  {name}: source={c.source_rows} loaded={c.loaded} merged={c.merged} skipped={c.skipped}"
                + (f" ({reasons})" if reasons else "")
            )
        if self.media is not None:
            m = self.media
            lines.append(
                f"  media: urls={m['urls_total']} already_hosted={m['already_hosted']} rehosted={m['rehosted']}"
                f" deduplicated={m['deduplicated']} failed={m['failed']} {m['fail_reasons']}"
            )
        lines.append(f"  warnings={len(self.warnings)} checks={self.checks}")
        return lines


def _iso(dt: datetime) -> str:
    return dt.astimezone(UTC).isoformat().replace("+00:00", "Z")
