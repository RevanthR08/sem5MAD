"""One-off data repair for rows written before the workflow fixes.

1. Reports waiting for citizen verification get resolved_at (the time the repair
   was submitted), so their SLA clock stops instead of showing them as overdue.
2. Assigned / in-progress reports that only have a team name get linked to the
   demo field worker, so they appear in the Field Ops queue.

Safe to run more than once. Run from the project root:
    python -m backend.db.migrate_fix_workflow_data
"""
import psycopg2
from backend.app.core.config import settings

DEMO_FIELD_WORKER_ID = "10000000-0000-0000-0000-000000000003"


def migrate():
    conn = psycopg2.connect(settings.DATABASE_URL)
    cur = conn.cursor()

    cur.execute("""
        UPDATE reports r
        SET resolved_at = COALESCE(
            (SELECT MAX(t.created_at) FROM report_timeline t
             WHERE t.report_id = r.id AND t.new_status = 'RESOLUTION_SUBMITTED'),
            r.updated_at)
        WHERE r.status = 'RESOLUTION_SUBMITTED' AND r.resolved_at IS NULL;
    """)
    print(f"resolved_at backfilled on {cur.rowcount} report(s)")

    cur.execute("""
        UPDATE reports
        SET assigned_to = %s
        WHERE status IN ('ASSIGNED', 'IN_PROGRESS', 'BLOCKED', 'RESOLUTION_SUBMITTED')
          AND assigned_to IS NULL AND assigned_team IS NOT NULL;
    """, (DEMO_FIELD_WORKER_ID,))
    print(f"assigned_to linked on {cur.rowcount} report(s)")

    # A seeded Unsplash photo was removed upstream; point it at a working image
    dead = "https://images.unsplash.com/photo-1541888946425-d0fbb186156f?w=800"
    live = "https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800"
    cur.execute("UPDATE report_media SET url = %s WHERE url = %s;", (live, dead))
    media = cur.rowcount
    cur.execute("""
        UPDATE reports SET
            resolution_before_photo = CASE WHEN resolution_before_photo = %s THEN %s ELSE resolution_before_photo END,
            resolution_after_photo = CASE WHEN resolution_after_photo = %s THEN %s ELSE resolution_after_photo END
        WHERE resolution_before_photo = %s OR resolution_after_photo = %s;
    """, (dead, live, dead, live, dead, dead))
    print(f"dead photo link replaced on {media} media row(s) and {cur.rowcount} report(s)")

    conn.commit()
    cur.close()
    conn.close()


if __name__ == "__main__":
    migrate()
