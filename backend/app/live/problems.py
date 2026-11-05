"""One row and one alert per problem, also across restarts (SD §6.7, research R5).

Opening or closing marks the row inside the caller's transaction and returns the text to send. The
caller sends it after commit, so a rolled-back cycle says nothing and a retried one says it once.
"""

from __future__ import annotations

from collections.abc import Iterable
from datetime import datetime

from sqlalchemy import update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.db.models import LiveProblem

_OPENED = {
    "format": "تغيّر شكل صفحة {subject}: توقف استخدامه حتى يُصلَح المحلل.",
    "down": "المصدر {subject} متوقف بعد محاولات متتالية فاشلة.",
    "both_down": "كل المصادر المفعّلة متوقفة: المباريات عادت إلى التقدير بالساعة.",
    "disagree": "المصادر مختلفة على نتيجة المباراة {subject}: بقيت النتيجة المقبولة.",
    "stale": "المباراة {subject} بلا قراءة حديثة: عادت إلى التقدير بالساعة.",
    "robots": "تغيّر ملف robots.txt للموقع {subject}: راجع القواعد.",
    "unknown_status": "ظهرت حالة غير معروفة في {subject}: احتُسبت نتيجتها الأعلى وأُهملت حالتها.",
    "stuck": "أُنهيت المباراة {subject} عند الحد الزمني بآخر نتيجة: لم يغلقها أي مصدر.",
}
_CLOSED = {
    "format": "عاد {subject} صالحًا.",
    "down": "عاد المصدر {subject} للعمل.",
    "both_down": "عاد مصدر واحد على الأقل للعمل.",
    "disagree": "انتهى الخلاف على نتيجة المباراة {subject}.",
    "stale": "عادت قراءات المباراة {subject}.",
    "robots": "عاد ملف robots.txt للموقع {subject} مطابقًا.",
    "unknown_status": "لم تعد في {subject} حالة غير معروفة.",
    "stuck": "أُغلق تنبيه إنهاء المباراة {subject} عند الحد الزمني.",
}


def _text(templates: dict[str, str], key: str, raw_ref: str | None = None) -> str:
    kind, _, subject = key.partition(":")
    message = templates[kind].format(subject=subject)
    return f"{message}\nالصفحة المحفوظة: {raw_ref}" if raw_ref else message


def open_problem(session: Session, key: str, now: datetime, *, raw_ref: str | None = None) -> str | None:
    """The alert text when this opens the problem; ``None`` when it's already open."""
    fresh = session.execute(
        insert(LiveProblem)
        .values(key=key, opened_at=now, raw_ref=raw_ref, alerted_at=now)
        .on_conflict_do_nothing(index_elements=[LiveProblem.key])
        .returning(LiveProblem.key)
    ).first()
    if fresh is None:
        reopened = session.execute(
            update(LiveProblem)
            .where(LiveProblem.key == key, LiveProblem.closed_at.is_not(None))
            .values(opened_at=now, closed_at=None, raw_ref=raw_ref, alerted_at=now, recovered_alerted_at=None)
            .returning(LiveProblem.key)
        ).first()
        if reopened is None:
            return None
    return _text(_OPENED, key, raw_ref)


def close_problem(session: Session, key: str, now: datetime) -> str | None:
    """The recovery text when this closes the problem; ``None`` when it wasn't open."""
    closed = session.execute(
        update(LiveProblem)
        .where(LiveProblem.key == key, LiveProblem.closed_at.is_(None))
        .values(closed_at=now, recovered_alerted_at=now)
        .returning(LiveProblem.key)
    ).first()
    return None if closed is None else _text(_CLOSED, key)


def sync_problems(
    session: Session,
    *,
    opened: Iterable[str] = (),
    closed: Iterable[str] = (),
    now: datetime,
    raw_ref: str | None = None,
) -> list[str]:
    """Open and close a batch; the alert texts to send after commit."""
    texts = [open_problem(session, key, now, raw_ref=raw_ref) for key in opened]
    texts += [close_problem(session, key, now) for key in closed]
    return [text for text in texts if text is not None]
