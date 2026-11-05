"""The Celery app ``app.workers`` that ``vps2.yml`` and the home box run (research R13).

Lane B2's tasks plug into it: ``app.adapters.tasks`` and ``app.adapters.media_tasks`` are
included, and ``app.adapters.schedule`` supplies the beat schedule, when those modules
exist, so this app can merge before them. Importing this package never loads
``app.settings`` or ``app.db``: the home box has no database (``config.py``).
"""

from __future__ import annotations

import importlib
import importlib.util
from collections.abc import Callable, Iterable
from typing import Any

from celery import Celery
from kombu import Queue

from app.workers import logs  # noqa: F401 - registers the JSON log handler
from app.workers.base import BaseTask
from app.workers.config import get_worker_settings

QUEUE_NAMES = ("scrape", "scrape_home", "imports", "maintenance", "media", "live", "notifications")
TASK_MODULES = ("app.adapters.tasks", "app.adapters.media_tasks", "app.notifications.tasks", "app.live.tasks")
SCHEDULE_MODULES = ("app.adapters.schedule", "app.notifications.schedule", "app.live.schedule")
ROUTER_MODULE = "app.adapters.tasks"


def existing_modules(names: Iterable[str]) -> list[str]:
    """The importable modules among ``names``; a missing parent package counts as missing."""
    found: list[str] = []
    for name in names:
        try:
            if importlib.util.find_spec(name) is not None:
                found.append(name)
        except (ImportError, ValueError):
            continue
    return found


def _module_schedule(module: str) -> dict[str, Any]:
    """One module's ``BEAT_SCHEDULE``, or ``{}`` when it doesn't exist yet."""
    try:
        loaded = importlib.import_module(module)
    except ModuleNotFoundError as exc:
        if exc.name and (module == exc.name or module.startswith(f"{exc.name}.")):
            return {}
        raise
    schedule = getattr(loaded, "BEAT_SCHEDULE", {})
    return dict(schedule)


def load_beat_schedule(modules: str | Iterable[str] = SCHEDULE_MODULES) -> dict[str, Any]:
    """The merge of every schedule module's ``BEAT_SCHEDULE`` (research R21).

    A missing module (or its parent package) contributes nothing. Two modules declaring the same
    entry name is a programming error and raises, so one beat entry never silently shadows another.
    An error inside an existing module propagates.
    """
    names = (modules,) if isinstance(modules, str) else tuple(modules)
    merged: dict[str, Any] = {}
    for module in names:
        for entry, definition in _module_schedule(module).items():
            if entry in merged:
                raise ValueError(f"duplicate beat entry {entry!r} (declared twice in {names})")
            merged[entry] = definition
    return merged


def route(name: str, args: Any = None, kwargs: Any = None, options: Any = None, task: Any = None, **_: Any) -> Any:
    """Resolve a task's queue through the adapters' router, imported on first use (B2-R1-19).

    ``celery call`` imports only this package, so registering the router object at app creation
    would need ``app.adapters.tasks`` (and the database) on the home box. Importing it here, per
    publish, keeps ``import app.workers`` database-free while ``adapters.fetch`` still routes right.
    """
    del options, task
    if not existing_modules([ROUTER_MODULE]):
        return None
    module = importlib.import_module(ROUTER_MODULE)
    router: Any = module.IngestionRouter()
    return router.route_for_task(name, args=args, kwargs=kwargs)


BROKER_TRANSPORT_OPTIONS: dict[str, Any] = {
    "global_keyprefix": "celery:",  # the home box's ACL allows ~celery:*
    # A broker reply lost on the way (the home box's tunnel inside a smaller VPN, 2026-11-02) left the
    # worker blocked in a read for 20 hours. kombu's BRPOP returns every second, so a 30 s read
    # timeout only fires on a dead connection, which kombu then drops and reconnects.
    "socket_timeout": 30,
    "socket_connect_timeout": 10,
    "socket_keepalive": True,
    "health_check_interval": 25,  # redis-py pings a connection idle this long before using it
}


def create_app() -> Celery:
    celery = Celery("madar", broker=get_worker_settings().broker_url, task_cls=BaseTask)
    celery.conf.update(
        broker_transport_options=BROKER_TRANSPORT_OPTIONS,
        broker_connection_retry_on_startup=True,
        result_backend=None,
        task_ignore_result=True,
        task_acks_late=True,
        task_reject_on_worker_lost=True,
        worker_prefetch_multiplier=1,
        task_serializer="json",
        result_serializer="json",
        accept_content=["json"],
        timezone="UTC",
        enable_utc=True,
        task_queues=[Queue(name) for name in QUEUE_NAMES],
        task_default_queue="maintenance",
        include=existing_modules(TASK_MODULES),
        beat_schedule=load_beat_schedule(),
        task_routes=(route,),
    )
    return celery


app = create_app()


def task(**options: Any) -> Callable[[Callable[..., Any]], Any]:
    """Declare a task on the shared app with the base class, bound (``self`` is the first argument)."""
    decorator: Callable[[Callable[..., Any]], Any] = app.task(base=BaseTask, bind=True, **options)
    return decorator
