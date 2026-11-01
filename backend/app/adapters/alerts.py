"""Telegram alerts for the importers (R17): one POST, logged, never raised.

The alert must never fail a run: a source that is down is exactly when the network or the token may
be wrong too. Without ``TELEGRAM_BOT_TOKEN`` and ``TELEGRAM_CHAT_ID`` the text is logged only, so a
developer's stack runs quiet (R17).
"""

from __future__ import annotations

import logging

import httpx

from app.adapters.config import get_adapter_settings

log = logging.getLogger(__name__)

TELEGRAM_HOST = "api.telegram.org"
TIMEOUT_SECONDS = 5.0


def send_alert(text: str, *, client: httpx.Client | None = None) -> bool:
    """Post ``text`` to the configured chat; ``True`` when Telegram accepted it.

    The URL is built from :data:`TELEGRAM_HOST`, so no other host can ever be contacted, and the
    token travels in the path of one request that is never logged (constitution V).
    """
    target = get_adapter_settings().telegram_target()
    if target is None:
        log.warning("alert_not_sent", extra={"why": "telegram_not_configured", "text": text})
        return False
    token, chat_id = target
    if client is not None:
        return _post(client, token, chat_id, text)
    with httpx.Client(timeout=httpx.Timeout(TIMEOUT_SECONDS), follow_redirects=False) as own:
        return _post(own, token, chat_id, text)


def _post(client: httpx.Client, token: str, chat_id: str, text: str) -> bool:
    url = f"https://{TELEGRAM_HOST}/bot{token}/sendMessage"
    try:
        response = client.post(url, json={"chat_id": chat_id, "text": text, "disable_web_page_preview": True})
    except httpx.HTTPError as exc:
        log.error("alert_failed", extra={"why": repr(exc)})
        return False
    if response.status_code >= 400:
        # The response body may echo the request URL; only the status is logged.
        log.error("alert_rejected", extra={"status": response.status_code})
        return False
    log.info("alert_sent", extra={"text": text})
    return True
