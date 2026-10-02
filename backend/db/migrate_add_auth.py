"""Adds password login to an existing database.

1. Adds users.password_hash (if missing).
2. Gives the four seeded demo accounts the demo password, only if they have none.

Safe to run more than once. Run from the project root:
    python -m backend.db.migrate_add_auth
"""
import psycopg2
from backend.app.core.config import settings
from backend.app.core.security import hash_password
from backend.db.seed_data import DEMO_PASSWORD, DEMO_USER_IDS


def migrate():
    conn = psycopg2.connect(settings.DATABASE_URL)
    cur = conn.cursor()
    cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash TEXT;")
    updated = 0
    for user_id in DEMO_USER_IDS:
        cur.execute("UPDATE users SET password_hash = %s WHERE id = %s AND password_hash IS NULL;",
                    (hash_password(DEMO_PASSWORD), user_id))
        updated += cur.rowcount
    conn.commit()
    print(f"password_hash column ready; demo password set on {updated} account(s)")
    cur.close()
    conn.close()


if __name__ == "__main__":
    migrate()
