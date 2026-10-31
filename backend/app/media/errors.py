"""The failure type shared by fetching, encoding and storing media."""

from __future__ import annotations


class RehostError(Exception):
    """A media file that can't be fetched or turned into an asset; ``reason`` is a short stable code."""

    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason
