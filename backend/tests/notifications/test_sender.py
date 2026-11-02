"""The real FCM sender: one page, one outcome per message, and no page-wide failure (B1-R1-1, -2, -6, B1-R2-1).

``firebase_admin.messaging.send_each`` is stubbed, so the mapping from a ``BatchResponse`` to
``SendOutcome`` is the code under test: which errors mean a dead token, which mean "try later", and
which mean "this device did not get it, the rest of the page still does". A transient error is sent
again for that device alone, after a short backoff, and only what is still unreachable is reported
``retryable``.
"""

from __future__ import annotations

from typing import Any

import pytest
from firebase_admin import exceptions, messaging

from app.notifications import sender as sender_module
from app.notifications.messages import PushMessage
from app.notifications.sender import RETRY_DELAYS, FcmSender
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
    """The stubbed ``send_each``: records each batch and the backoff sleeps.

    ``answers`` is the reply to the first call; ``then[n]`` is the reply to the n-th re-send (a
    list of responses, or an exception to raise as a whole-call failure).
    """

    def __init__(self) -> None:
        self.answers: list[messaging.SendResponse] = []
        self.then: list[list[messaging.SendResponse] | BaseException] = []
        self.batches: list[list[Any]] = []
        self.sleeps: list[float] = []

    def __call__(self, batch: list[Any], dry_run: bool = False) -> messaging.BatchResponse:
        self.batches.append(list(batch))
        answer = self.answers if len(self.batches) == 1 else self.then[len(self.batches) - 2]
        if isinstance(answer, BaseException):
            raise answer
        return messaging.BatchResponse(answer)

    def tokens(self, call: int) -> list[str]:
        """The registration tokens of the n-th ``send_each`` call."""
        return [message.fid for message in self.batches[call]]


@pytest.fixture
def stub(monkeypatch) -> _Stub:
    """``FcmSender`` on the real ``messaging`` module, with ``send_each`` and the backoff sleep stubbed."""
    stub = _Stub()
    monkeypatch.setattr(FcmSender, "_messaging", lambda self: messaging)
    monkeypatch.setattr(messaging, "send_each", stub)
    monkeypatch.setattr(sender_module, "sleep", stub.sleeps.append)
    return stub


def _unavailable() -> messaging.SendResponse:
    return _failed(exceptions.UnavailableError("The service is currently unavailable."))


def test_each_message_keeps_its_own_outcome(stub):
    """A page mixes success, a dead token, an outage and a bad message field."""
    tokens = ["ok-token", "dead-token", "busy-token", "bad-link-token"]
    stub.answers = [
        _ok(),
        _failed(messaging.UnregisteredError("Requested entity was not found.")),
        _unavailable(),
        _failed(exceptions.InvalidArgumentError("webpush.fcm_options.link must be an https URL")),
    ]
    stub.then = [[_unavailable()] for _ in RETRY_DELAYS]

    outcome = FcmSender(None).send_page([_push(token) for token in tokens])

    assert (outcome.sent, outcome.failed) == (1, 1)
    assert outcome.unregistered == ("dead-token",)
    assert outcome.retryable == ("busy-token",)


def test_a_bad_message_field_is_not_a_dead_token(stub):
    """``INVALID_ARGUMENT`` about the payload must never clear the device's token (B1-R1-2)."""
    stub.answers = [_failed(exceptions.InvalidArgumentError("webpush.fcm_options.link must be an https URL"))]

    outcome = FcmSender(None).send_page([_push("live-token")])

    assert outcome.unregistered == ()
    assert (outcome.sent, outcome.failed) == (0, 1)


# --- B1-R2-1: a transient per-message error is sent again, for that device only -------------------


def test_a_transient_failure_is_sent_again_for_that_device_only(stub):
    """A device that got the message is never in a re-send; the one FCM could not take is."""
    stub.answers = [_ok(), _unavailable()]
    stub.then = [[_ok()]]

    outcome = FcmSender(None).send_page([_push("ok-token"), _push("busy-token")])

    assert (outcome.sent, outcome.failed, outcome.retryable) == (2, 0, ())
    assert stub.tokens(0) == ["ok-token", "busy-token"]
    assert stub.tokens(1) == ["busy-token"]
    assert stub.sleeps == [RETRY_DELAYS[0]]


@pytest.mark.parametrize(
    "error",
    [
        exceptions.UnavailableError("The service is currently unavailable."),
        exceptions.InternalError("Internal error encountered."),
        exceptions.DeadlineExceededError("Timed out while making an API call."),
        messaging.QuotaExceededError("Quota exceeded."),
        exceptions.UnknownError("Unknown error while making a remote service call."),
    ],
    ids=["503-unavailable", "500-internal", "timeout", "429-quota", "transport-unknown"],
)
def test_every_transient_error_kind_is_sent_again(stub, error):
    stub.answers = [_failed(error)]
    stub.then = [[_ok()]]

    outcome = FcmSender(None).send_page([_push("busy-token")])

    assert (outcome.sent, outcome.failed, outcome.retryable) == (1, 0, ())
    assert len(stub.batches) == 2


def test_a_device_still_unreachable_after_the_backoff_is_reported_retryable(stub):
    """The re-sends are bounded; what FCM still cannot take is neither ``sent`` nor ``failed``."""
    stub.answers = [_ok(), _unavailable()]
    stub.then = [[_unavailable()] for _ in RETRY_DELAYS]

    outcome = FcmSender(None).send_page([_push("ok-token"), _push("busy-token")])

    assert (outcome.sent, outcome.failed, outcome.retryable) == (1, 0, ("busy-token",))
    assert [len(batch) for batch in stub.batches] == [2, *[1 for _ in RETRY_DELAYS]]
    assert stub.sleeps == list(RETRY_DELAYS)


@pytest.mark.parametrize(
    "error",
    [
        exceptions.InvalidArgumentError("webpush.fcm_options.link must be an https URL"),
        messaging.SenderIdMismatchError("SenderId mismatch."),
        messaging.ThirdPartyAuthError("Third party auth error."),
    ],
    ids=["bad-field", "sender-mismatch", "third-party-auth"],
)
def test_an_error_a_resend_cannot_fix_is_not_retried(stub, error):
    stub.answers = [_failed(error)]

    outcome = FcmSender(None).send_page([_push("device-token")])

    assert (outcome.sent, outcome.failed, outcome.retryable) == (0, 1, ())
    assert len(stub.batches) == 1
    assert stub.sleeps == []


def test_a_whole_call_failure_on_a_resend_keeps_what_was_delivered(stub):
    """Raising here would re-send the page whole and give ``ok-token`` its message twice."""
    stub.answers = [_ok(), _unavailable()]
    stub.then = [exceptions.UnavailableError("The service is currently unavailable.")]

    outcome = FcmSender(None).send_page([_push("ok-token"), _push("busy-token")])

    assert (outcome.sent, outcome.failed, outcome.retryable) == (1, 0, ("busy-token",))
    assert len(stub.batches) == 2


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
