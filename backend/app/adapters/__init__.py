"""Lane B2's ingestion code: sources, resolution, upsert, tasks and the schedule.

Nothing here is imported by the public API. The fetch path (``base``, ``fetcher``,
``ratelimit``, ``messages`` and the fetch/parse parts of each adapter) runs on the owner's home
box and must import neither ``app.db`` nor ``app.settings`` (FR-028, research R21).
"""
