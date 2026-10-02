import threading
import time
import psycopg2
from psycopg2 import pool
from psycopg2.extras import RealDictCursor
from contextlib import contextmanager
from backend.app.core.config import settings

# Opening a connection to the hosted database costs a DNS lookup plus a TLS
# handshake (1-2 s, and DNS occasionally fails), so connections are pooled
# and reused instead of opened per request.
POOL_MAX = 10
IDLE_CHECK_SECONDS = 20  # ping connections idle longer than this before reuse

_pool = None
_pool_lock = threading.Lock()
_slots = threading.BoundedSemaphore(POOL_MAX)
_last_used = {}


def _with_retries(fn, attempts: int = 3):
    """Retry transient connection failures such as DNS lookup errors."""
    for attempt in range(attempts):
        try:
            return fn()
        except psycopg2.OperationalError:
            if attempt == attempts - 1:
                raise
            time.sleep(0.5 * (attempt + 1))


def _get_pool():
    global _pool
    if _pool is None:
        with _pool_lock:
            if _pool is None:
                _pool = _with_retries(lambda: pool.ThreadedConnectionPool(
                    1, POOL_MAX, settings.DATABASE_URL,
                    keepalives=1, keepalives_idle=30, keepalives_interval=10, keepalives_count=3,
                ))
    return _pool


def _healthy(conn) -> bool:
    if conn.closed:
        return False
    if time.monotonic() - _last_used.get(id(conn), 0) < IDLE_CHECK_SECONDS:
        return True
    try:
        with conn.cursor() as c:
            c.execute("SELECT 1;")
        conn.rollback()
        return True
    except psycopg2.Error:
        return False


def _acquire():
    p = _get_pool()
    for _ in range(3):
        conn = _with_retries(p.getconn)
        if _healthy(conn):
            return conn
        p.putconn(conn, close=True)
    return _with_retries(p.getconn)


@contextmanager
def get_db():
    _slots.acquire()
    conn = None
    broken = False
    try:
        conn = _acquire()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        try:
            yield cur
            conn.commit()
        except (psycopg2.OperationalError, psycopg2.InterfaceError):
            broken = True
            raise
        except Exception:
            conn.rollback()
            raise
        finally:
            cur.close()
    finally:
        if conn is not None:
            _last_used[id(conn)] = time.monotonic()
            _get_pool().putconn(conn, close=broken or conn.closed)
        _slots.release()

def execute_query(query: str, params: tuple = None, fetch_one: bool = False, fetch_all: bool = True):
    with get_db() as cur:
        cur.execute(query, params or ())
        if fetch_one:
            return cur.fetchone()
        if fetch_all:
            return cur.fetchall()
        return None
