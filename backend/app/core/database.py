import psycopg2
from psycopg2.extras import RealDictCursor
from contextlib import contextmanager
from backend.app.core.config import settings

@contextmanager
def get_db():
    conn = psycopg2.connect(settings.DATABASE_URL)
    try:
        cur = conn.cursor(cursor_factory=RealDictCursor)
        yield cur
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        cur.close()
        conn.close()

def execute_query(query: str, params: tuple = None, fetch_one: bool = False, fetch_all: bool = True):
    with get_db() as cur:
        cur.execute(query, params or ())
        if fetch_one:
            return cur.fetchone()
        if fetch_all:
            return cur.fetchall()
        return None
