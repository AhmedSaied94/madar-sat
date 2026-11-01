"""The real FCM sender: one page, one outcome per message, and no page-wide failure (B1-R1-1, -2, -6).

``firebase_admin.messaging.send_each`` is stubbed, so the mapping from a ``BatchResponse`` to
``SendOutcome`` is the code under test: which errors mean a dead token, which mean "try later", and
which mean "this device did not get it, the rest of the page still does".
"""

from __future__ import annotations

from typing import Any

import pytest
from firebase_admin import exceptions, messaging

from app.notifications.messages import PushMessage
from app.notifications.sender import FcmSender
from app.workers.base import Retryable

PWA = "https://app.example"


def _push(token: str) -> PushMessage:
    return PushMessage(
        token=token,
        title="الأهلي × الزمالك بعد 15 دقيقة",
        body="اضغط لعرض القنوات والترددات",
        data={"type": "kickoff_reminder", "match_id": "1", "route": "/match/1"},
        tag="match_1",
        link=f"{PWA}/match/1",
    )


def _ok() -> messaging.SendResponse:
    return messaging.SendResponse({"name": "projects/p/messages/1"}, None)


def _failed(exception: BaseException) -> messaging.SendResponse:
    return messaging.SendResponse(None, exception)


class _Stub:
    """The stubbed ``send_each``: records each batch, answers with ``self.answers``."""

    def __init__(self) -> None:
        self.answers: list[messaging.SendResponse] = []
        self.batches: list[list[Any]] = []

    def __call__(self, batch: list[Any], dry_run: bool = False) -> messaging.BatchResponse:
        self.batches.append(list(batch))
        return messaging.BatchResponse(self.answers)


@pytest.fixture
def stub(monkeypatch) -> _Stub:
    """``FcmSender`` on the real ``messaging`` module, with ``send_each`` stubbed."""
    stub = _Stub()
    monkeypatch.setattr(FcmSender, "_messaging", lambda self: messaging)
    monkeypatch.setattr(messaging, "send_each", stub)
    return stub


def test_each_message_keeps_its_own_outcome(stub):
    """A page mixes success, a dead token, an outage and a bad message field."""
    tokens = ["ok-token", "dead-token", "busy-token", "bad-link-token"]
    stub.answers = [
        _ok(),
        _failed(messaging.UnregisteredError("Requested entity was not found.")),
        _failed(exceptions.UnavailableError("The service is currently unavailable.")),
        _failed(exceptions.InvalidArgumentError("webpush.fcm_options.link must be an https URL")),
    ]

    outcome = FcmSender(None).send_page([_push(token) for token in tokens])

    assert (outcome.sent, outcome.failed) == (1, 2)
    assert outcome.unregistered == ("dead-token",)


def test_a_bad_message_field_is_not_a_dead_token(stub):
    """``INVALID_ARGUMENT`` about the payload must never clear the device's token (B1-R1-2)."""
    stub.answers = [_failed(exceptions.InvalidArgumentError("webpush.fcm_options.link must be an https URL"))]

    outcome = FcmSender(None).send_page([_push("live-token")])

    assert outcome.unregistered == ()
    assert (outcome.sent, outcome.failed) == (0, 1)


def test_an_invalid_registration_token_is_a_dead_token(stub):
    stub.answers = [
        _failed(exceptions.InvalidArgumentError("The registration token is not a valid FCM registration token"))
    ]

    outcome = FcmSender(None).send_page([_push("dead-token")])

    assert outcome.unregistered == ("dead-token",)
    assert (outcome.sent, outcome.failed) == (0, 0)


def test_an_empty_token_does_not_fail_the_whole_page(stub):
    """Encoding is per message: one unusable token is ``failed``, the rest still go out (B1-R1-1)."""
    stub.answers = [_ok()]

    outcome = FcmSender(None).send_page([_push(""), _push("good-token")])

    assert [len(batch) for batch in stub.batches] == [1]
    assert (outcome.sent, outcome.failed) == (1, 1)
    assert outcome.unregistered == ()


def test_a_page_of_only_unusable_tokens_never_calls_fcm(stub):
    outcome = FcmSender(None).send_page([_push("")])

    assert stub.batches == []
    assert (outcome.sent, outcome.failed) == (0, 1)


def test_a_whole_call_failure_is_retryable(stub, monkeypatch):
    def boom(batch: list[Any], dry_run: bool = False) -> messaging.BatchResponse:
        raise exceptions.UnavailableError("The service is currently unavailable.")

    monkeypatch.setattr(messaging, "send_each", boom)

    with pytest.raises(Retryable):
        FcmSender(None).send_page([_push("device-token")])


def test_the_dry_run_flag_reaches_fcm(stub, monkeypatch):
    seen: list[bool] = []

    def send_each(batch: list[Any], dry_run: bool = False) -> messaging.BatchResponse:
        seen.append(dry_run)
        return messaging.BatchResponse([_ok() for _ in batch])

    monkeypatch.setattr(messaging, "send_each", send_each)

    FcmSender(None, dry_run=True).send_page([_push("device-token")])

    assert seen == [True]


def test_an_empty_page_returns_without_touching_fcm(stub):
    outcome = FcmSender(None).send_page([])

    assert stub.batches == []
    assert (outcome.sent, outcome.failed, outcome.unregistered) == (0, 0, ())
