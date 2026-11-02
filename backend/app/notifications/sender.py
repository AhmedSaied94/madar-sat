"""The push sender: a protocol, the FCM implementation and one batch call per page (research R9).

``firebase-admin`` is imported only where it is used, so the API process and the home box never load
it. The credentials file is read once per worker; ``FCM_DRY_RUN`` uses FCM's own dry run.
"""

from __future__ import annotations

import inspect
import logging
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path
from time import sleep
from typing import Any, Protocol

from app.notifications.messages import CHANNEL_ID, ICON, PushMessage
from app.workers.base import Retryable

log = logging.getLogger("madar.notifications")

ICON_PATH = "/icons/Icon-192.png"
BADGE_PATH = "/icons/Icon-maskable-192.png"
# A device FCM could not take for a moment (503, 500, 429, a timeout) is sent the message again, for
# that device alone, after each of these waits (seconds) (B1-R2-1).
RETRY_DELAYS = (1.0, 2.0, 4.0)


@dataclass(frozen=True)
class SendOutcome:
    """One page's result: delivered, failed, the tokens FCM says no longer exist, and the tokens it
    still could not take after the re-sends (``retryable``: neither delivered nor final)."""

    sent: int = 0
    failed: int = 0
    unregistered: tuple[str, ...] = ()
    retryable: tuple[str, ...] = ()


class PushSender(Protocol):
    def send_page(self, messages: Sequence[PushMessage]) -> SendOutcome: ...


@dataclass
class FcmSender:
    """``firebase_admin.messaging.send_each``: one HTTP call for ≤ 500 messages."""

    credentials_file: Path | None
    dry_run: bool = False
    pwa_origin: str | None = None

    @classmethod
    def from_settings(cls) -> FcmSender:
        from app.settings import get_settings

        settings = get_settings()
        return cls(
            credentials_file=settings.fcm_credentials_file,
            dry_run=settings.fcm_dry_run,
            pwa_origin=str(settings.pwa_origin) if settings.pwa_origin else None,
        )

    def _messaging(self) -> Any:
        import firebase_admin
        from firebase_admin import credentials, messaging

        if not firebase_admin._apps:  # one app per process
            if self.credentials_file is None:
                raise RuntimeError("FCM_CREDENTIALS_FILE is not set; the notifications worker cannot send")
            firebase_admin.initialize_app(credentials.Certificate(str(self.credentials_file)))
            log.info("fcm: initialized", extra={"dry_run": self.dry_run})
        return messaging

    def _message(self, messaging: Any, message: PushMessage) -> Any:
        android = messaging.AndroidConfig(
            collapse_key=message.tag,
            notification=messaging.AndroidNotification(tag=message.tag, channel_id=CHANNEL_ID, icon=ICON),
        )
        webpush = None
        if message.link:
            origin = message.link.split("/match/")[0]
            webpush = messaging.WebpushConfig(
                notification=messaging.WebpushNotification(
                    tag=message.tag, icon=f"{origin}{ICON_PATH}", badge=f"{origin}{BADGE_PATH}"
                ),
                fcm_options=messaging.WebpushFCMOptions(link=message.link),
            )
        return messaging.Message(
            **{_token_field(messaging): message.token},
            notification=messaging.Notification(title=message.title, body=message.body),
            data=message.data,
            android=android,
            webpush=webpush,
        )

    def send_page(self, messages: Sequence[PushMessage]) -> SendOutcome:
        if not messages:
            return SendOutcome()
        messaging = self._messaging()
        # A page must never fail whole because of one device: firebase-admin raises while encoding
        # a message with an empty fid, which used to turn the entire page into a retry (B1-R1-1).
        encoded: list[tuple[PushMessage, Any]] = []
        failed = 0
        for message in messages:
            if not _is_usable(message):
                failed += 1
                log.error("fcm_message_unusable", extra={"why": "empty_token"})
                continue
            try:
                encoded.append((message, self._message(messaging, message)))
            except Exception as exc:  # noqa: BLE001 - one bad message is one failed device
                failed += 1
                log.error("fcm_message_unencodable", extra={"why": repr(exc)})
        sent = 0
        unregistered: list[str] = []
        pending = encoded
        for attempt in range(len(RETRY_DELAYS) + 1):
            if not pending:
                break
            if attempt:
                sleep(RETRY_DELAYS[attempt - 1])
            try:
                response = messaging.send_each([wire for _, wire in pending], dry_run=self.dry_run)
            except Exception as exc:  # noqa: BLE001 - a whole-call failure is transient
                log.warning("fcm_call_failed", extra={"messages": len(pending), "why": repr(exc)})
                if attempt == 0:
                    raise Retryable(f"send_each failed: {exc!r}") from exc
                # A re-send cannot fail the page: raising now would re-send it whole to the devices
                # the earlier calls already reached. What is still pending is reported ``retryable``.
                break
            unsent: list[tuple[PushMessage, Any]] = []
            for (message, wire), result in zip(pending, response.responses, strict=True):
                if result.success:
                    sent += 1
                    continue
                problem = result.exception
                if _is_unregistered(messaging, problem):
                    unregistered.append(message.token)
                elif _is_transient(problem):
                    unsent.append((message, wire))
                else:
                    failed += 1
                    log.error("fcm_message_failed", extra={"why": repr(problem)})
            pending = unsent
        if pending:
            log.warning("fcm_messages_unreachable", extra={"devices": len(pending)})
        return SendOutcome(
            sent=sent,
            failed=failed,
            unregistered=tuple(unregistered),
            retryable=tuple(message.token for message, _ in pending),
        )


def _is_usable(message: PushMessage) -> bool:
    """A token FCM can address: no empty string, no blank, no NUL (B1-R1-1)."""
    token = message.token
    return bool(token and token.strip() and "\x00" not in token)


def _is_transient(exc: BaseException | None) -> bool:
    """FCM could not take the message just now: 503, 500, 429 (``QuotaExceededError`` is one), a
    timeout, or a transport error with no reply. Not "this message is wrong" (B1-R2-1)."""
    from firebase_admin import exceptions

    return isinstance(
        exc,
        (
            exceptions.UnavailableError,
            exceptions.InternalError,
            exceptions.ResourceExhaustedError,
            exceptions.DeadlineExceededError,
            exceptions.UnknownError,
        ),
    )


def _token_field(messaging: Any) -> str:
    """``firebase-admin`` 7 renamed ``Message.token`` to ``Message.fid``; support both."""
    return "fid" if "fid" in inspect.signature(messaging.Message.__init__).parameters else "token"


def _is_unregistered(messaging: Any, exc: BaseException | None) -> bool:
    """Only FCM's ``UNREGISTERED``, or an ``INVALID_ARGUMENT`` that names the registration token.

    FCM uses ``INVALID_ARGUMENT`` for bad message fields too (an ``http://`` ``fcm_options.link``,
    for one). Treating those as a dead token would wipe the page's tokens, and the app never
    re-sends an unchanged token (B1-R1-2).
    """
    if exc is None:
        return False
    if isinstance(exc, messaging.UnregisteredError):
        return True
    detail = str(exc).lower()
    if getattr(exc, "code", None) != "INVALID_ARGUMENT" and "invalid_argument" not in detail:
        return False
    return "registration token" in detail or "registration-token" in detail
