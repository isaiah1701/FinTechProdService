from threading import Lock

from mal_account_service.db import ping_database

_draining = False
_lock = Lock()


def mark_draining(signum: int | None = None, frame: object | None = None) -> None:
    del signum, frame
    global _draining
    with _lock:
        _draining = True


def is_draining() -> bool:
    with _lock:
        return _draining


def reset_draining_for_tests() -> None:
    global _draining
    with _lock:
        _draining = False


def readiness_status() -> tuple[bool, str]:
    if is_draining():
        return False, "draining"

    if not ping_database():
        return False, "database_unreachable"

    return True, "ready"
