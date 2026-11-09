"""The ``push`` problem: one alert, one recovery, and the size rules (T028, research R11)."""

from __future__ import annotations

from uuid import uuid4

from sqlalchemy import select, text

from app.db.models import Device, LiveProblem, NotificationOutbox
from app.notifications.dispatcher import dispatch_due
from tests import support
from tests.support import FakePushSender


def _devices(session, bag, count: int) -> list[Device]:
    devices = []
    for index in range(count):
        device = support.new_device(session, token=f"tok-{index}", push_token=f"push-alert-{index}")
        support.follow(session, device, match=bag.match.id)
        devices.append(device)
    return devices


def _row(session, bag, now) -> NotificationOutbox:
    row = NotificationOutbox(
        type="announcement",
        dedupe_key=f"announcement:alert:{uuid4().hex}",
        payload={"title": "خبر", "body": "نص", "route": "/"},
        audience={"kind": "all"},
        due_at=now,
        status="pending",
    )
    session.add(row)
    session.flush()
    return row


def _alerts(monkeypatch) -> list[str]:
    sent: list[str] = []

    def record(text: str) -> bool:
        sent.append(text)
        return True

    monkeypatch.setattr("app.adapters.alerts.send_alert", record)
    return sent


def _problem(session) -> LiveProblem | None:
    return session.scalar(
        select(LiveProblem).where(LiveProblem.key == "push").execution_options(populate_existing=True)
    )


def test_a_failed_send_opens_one_problem_and_a_good_one_closes_it(sync_session, frozen_now, monkeypatch):
    bag = support.create_match_sync(sync_session, frozen_now)
    devices = _devices(sync_session, bag, 12)
    failing = {str(device.push_token): "failed" for device in devices[:3]}
    _row(sync_session, bag, frozen_now)
    sent: list[str] = []
    monkeypatch.setattr("app.adapters.alerts.send_alert", lambda text: sent.append(text) or True)

    dispatch_due(sync_session, FakePushSender(failing), frozen_now)

    problem = _problem(sync_session)
    assert problem is not None and problem.closed_at is None
    assert len(sent) == 1

    # A second bad row does not repeat the alert; a good one closes it once.
    _row(sync_session, bag, frozen_now)
    dispatch_due(sync_session, FakePushSender(failing), frozen_now)
    assert len(sent) == 1

    _row(sync_session, bag, frozen_now)
    dispatch_due(sync_session, FakePushSender(), frozen_now)
    problem = _problem(sync_session)
    assert problem is not None and problem.closed_at is not None
    assert len(sent) == 2


def test_a_small_send_never_alerts_even_when_it_all_fails(sync_session, frozen_now, monkeypatch):
    bag = support.create_match_sync(sync_session, frozen_now)
    devices = _devices(sync_session, bag, 3)
    failing = {str(device.push_token): "failed" for device in devices}
    _row(sync_session, bag, frozen_now)
    sent = _alerts(monkeypatch)

    dispatch_due(sync_session, FakePushSender(failing), frozen_now)

    assert sent == []
    assert _problem(sync_session) is None


def test_a_share_over_twenty_percent_with_ten_devices_opens_it(sync_session, frozen_now, monkeypatch):
    bag = support.create_match_sync(sync_session, frozen_now)
    devices = _devices(sync_session, bag, 10)
    failing = {str(device.push_token): ("failed" if index < 3 else "ok") for index, device in enumerate(devices)}
    _row(sync_session, bag, frozen_now)
    sent = _alerts(monkeypatch)

    dispatch_due(sync_session, FakePushSender(failing), frozen_now)

    assert len(sent) == 1
    assert _problem(sync_session) is not None


def test_dead_tokens_are_not_failures(sync_session, frozen_now, monkeypatch):
    bag = support.create_match_sync(sync_session, frozen_now)
    devices = _devices(sync_session, bag, 12)
    dead = {str(device.push_token): "UNREGISTERED" for device in devices[:6]}
    _row(sync_session, bag, frozen_now)
    sent = _alerts(monkeypatch)

    dispatch_due(sync_session, FakePushSender(dead), frozen_now)

    assert sent == []
    assert _problem(sync_session) is None


def test_a_test_send_never_alerts(sync_session, frozen_now, monkeypatch):
    support.create_match_sync(sync_session, frozen_now)
    device = support.new_device(sync_session, token="test", push_token="push-test")
    row = NotificationOutbox(
        type="announcement",
        dedupe_key="test:alert",
        payload={"title": "تجربة", "body": "نص", "route": "/"},
        audience={"kind": "device", "device_id": device.id},
        due_at=frozen_now,
        status="pending",
    )
    sync_session.add(row)
    sync_session.flush()
    sent = _alerts(monkeypatch)

    dispatch_due(sync_session, FakePushSender({str(device.push_token): "failed"}), frozen_now)

    assert sent == []
    assert _problem(sync_session) is None


def test_a_cancelled_row_never_alerts(sync_session, frozen_now, monkeypatch):
    bag = support.create_match_sync(sync_session, frozen_now)
    _devices(sync_session, bag, 12)
    _row(sync_session, bag, frozen_now)
    from app.settings import get_settings

    monkeypatch.setattr(get_settings(), "push_types_off", "announcement", raising=False)
    sent = _alerts(monkeypatch)

    dispatch_due(sync_session, FakePushSender(), frozen_now)

    assert sent == []
    assert _problem(sync_session) is None


def test_a_row_that_exhausts_its_attempts_keeps_the_fcm_reason(sync_session, frozen_now):
    bag = support.create_match_sync(sync_session, frozen_now)
    _devices(sync_session, bag, 2)
    _row(sync_session, bag, frozen_now)
    from app.notifications.dispatcher import MAX_ATTEMPTS, PushRetryable
    from app.notifications.sender import SendOutcome

    class Outage:
        def send_page(self, messages):
            return SendOutcome(sent=0, failed=0, retryable=tuple(message.token for message in messages))

    for _ in range(MAX_ATTEMPTS - 1):
        dispatch_due(sync_session, Outage(), frozen_now)

    report = dispatch_due(sync_session, Outage(), frozen_now)

    assert report.failed_row_id is not None
    row = sync_session.get(NotificationOutbox, report.failed_row_id, populate_existing=True)
    assert row is not None
    assert row.status == "failed"
    assert row.error == "FCM retryable"
    assert PushRetryable("FCM 503").reason == "FCM 503"
    assert "push-alert" not in (row.error or "")


def test_the_failure_reason_reads_the_http_status_then_the_code():
    from app.notifications.sender import failure_reason

    class Response:
        status_code = 503

    class WithResponse(Exception):
        http_response = Response()

    class WithCode(Exception):
        code = "UNAVAILABLE"

    assert failure_reason(WithResponse()) == "FCM 503"
    assert failure_reason(WithCode()) == "FCM UNAVAILABLE"
    assert failure_reason(None) == "FCM failed"


def _alerts_after_commit(monkeypatch, session) -> list[tuple[str, bool, bool]]:
    """Each alert, with whether the dispatcher's transaction was still open and the problem row stored.

    The check reads through the test's connection (``session.bind``), so it opens nothing on the session.
    """
    seen: list[tuple[str, bool, bool]] = []

    def record(message: str) -> bool:
        in_transaction = session.in_transaction()
        stored = session.bind.execute(text("SELECT count(*) FROM live_problems WHERE key = 'push'")).scalar_one()
        seen.append((message, in_transaction, bool(stored)))
        return True

    monkeypatch.setattr("app.adapters.alerts.send_alert", record)
    return seen


def test_a_sender_refusing_every_send_alerts_once_after_commit(sync_session, frozen_now, monkeypatch):
    """B1-R1-5 (FR-029, SC-014): every device refused, one alert, sent once the row is committed."""
    bag = support.create_match_sync(sync_session, frozen_now)
    devices = _devices(sync_session, bag, 12)
    refused = {str(device.push_token): "failed" for device in devices}
    row = _row(sync_session, bag, frozen_now)
    seen = _alerts_after_commit(monkeypatch, sync_session)

    dispatch_due(sync_session, FakePushSender(refused), frozen_now)

    sync_session.refresh(row)
    assert (row.status, row.sent, row.failed) == ("sent", 0, 12)
    assert len(seen) == 1
    [(_text, in_transaction, stored)] = seen
    assert in_transaction is False, "the alert went out before the dispatcher committed"
    assert stored is True


def test_a_row_failed_at_max_attempts_alerts_once_after_commit(sync_session, frozen_now, monkeypatch):
    """B1-R1-5: the ``MAX_ATTEMPTS`` -> ``failed`` path opens the problem and alerts, after its commit."""
    from app.notifications.dispatcher import MAX_ATTEMPTS

    bag = support.create_match_sync(sync_session, frozen_now)
    _devices(sync_session, bag, 2)
    row = _row(sync_session, bag, frozen_now)
    seen = _alerts_after_commit(monkeypatch, sync_session)

    for _ in range(MAX_ATTEMPTS - 1):
        dispatch_due(sync_session, FakePushSender(fail_every_page=True), frozen_now)
    assert seen == []

    report = dispatch_due(sync_session, FakePushSender(fail_every_page=True), frozen_now)

    assert report.failed_row_id == row.id
    sync_session.refresh(row)
    assert row.status == "failed"
    problem = _problem(sync_session)
    assert problem is not None and problem.closed_at is None
    assert len(seen) == 1
    [(_text, in_transaction, stored)] = seen
    assert in_transaction is False, "the alert went out before the failed row was committed"
    assert stored is True
