import threading
import time
from typing import Any, Callable, Tuple

from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session
from sqlalchemy.pool import NullPool

import test_tools as tt


START_TEST_BLOCK = 115
# hived's default psql-contexts-compaction-threshold
THRESHOLD_PAGES = 64
TIMEOUT_SECONDS = 120
# blocks hived must keep producing while a compaction cannot get its lock
BLOCKS_WHILE_SKIPPING = 3

# An application in an eternal CALL main()-style loop: each iteration commits and, at the head,
# waits for the next block.
APP_LOOP = """
DO $do$
DECLARE
    __range hive.blocks_range;
BEGIN
    WHILE NOT EXISTS ( SELECT 1 FROM compaction_app.stop ) LOOP
        CALL hive.app_next_iteration( ARRAY[ 'compaction_app' ], __range );
    END LOOP;
END
$do$
"""


def heap_pages(session: Session) -> int:
    pages = int(session.execute(text("SELECT hive.contexts_heap_pages()")).scalar_one())
    session.commit()
    return pages


# Sessions VACUUM FULL may keep the filler rows for: one with a transaction not newer than their DELETE in any
# database (VACUUM FULL's own snapshot does not see past it), or one of the test database with an older snapshot.
OLDER_SNAPSHOTS = """
SELECT pid, datname, backend_type, application_name, state, backend_xid::TEXT AS xid, backend_xmin::TEXT AS xmin,
       xact_start, wait_event_type, wait_event, left( query, 200 ) AS query
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
  AND ( age( backend_xid ) >= age( CAST( :deleted_by AS xid ) )
        OR ( datname = current_database() AND age( backend_xmin ) >= age( CAST( :deleted_by AS xid ) ) ) )
ORDER BY pid
"""


def older_snapshots(session: Session, deleted_by: str) -> list[str]:
    rows = (
        session.execute(text(OLDER_SNAPSHOTS), {"deleted_by": deleted_by})
        .mappings()
        .all()
    )
    session.commit()
    return [", ".join(f"{key}={value}" for key, value in row.items()) for row in rows]


def wait_for_no_older_snapshots(session: Session, deleted_by: str) -> None:
    deadline = time.monotonic() + TIMEOUT_SECONDS
    logged: list[str] = []
    while holders := older_snapshots(session, deleted_by):
        if holders != logged:
            tt.logger.info(
                f"waiting for snapshots older than the DELETE (xid {deleted_by}): {holders}"
            )
            logged = holders
        assert time.monotonic() < deadline, (
            f"snapshots older than the DELETE (xid {deleted_by}) remained: {holders}"
        )
        time.sleep(0.2)


def wait_for_log_line(node: Any, matches: Callable[[str], bool], what: str) -> str:
    deadline = time.monotonic() + TIMEOUT_SECONDS
    while True:
        log: str = (node.directory / "stderr.log").read_text(errors="replace")
        for line in log.splitlines():
            if matches(line):
                return line
        assert time.monotonic() < deadline, f"hived never logged {what}"
        time.sleep(1)


def test_contexts_compaction(
    prepared_networks_and_database_12_8: Tuple[Any, Session],
) -> None:
    tt.logger.info("Start test_contexts_compaction")

    # GIVEN
    networks_builder, session = prepared_networks_and_database_12_8
    node_under_test = networks_builder.networks[1].node("ApiNode0")
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)

    session.execute(text("CREATE SCHEMA compaction_app"))
    session.execute(text("CREATE TABLE compaction_app.stop( stop BOOLEAN )"))
    session.execute(
        text(
            "SELECT hive.app_create_context( 'compaction_app', 'compaction_app', _is_forking => FALSE )"
        )
    )
    session.commit()

    app_errors: list[Exception] = []

    def run_app() -> None:
        try:
            with session.bind.connect().execution_options(
                isolation_level="AUTOCOMMIT"
            ) as app:
                app.execute(text(APP_LOOP))
        except Exception as error:  # reported by the main thread
            app_errors.append(error)

    app_thread = threading.Thread(target=run_app)
    app_thread.start()

    # Taken before the DELETE below, as applications' sessions or other databases' work may hold them: an older
    # snapshot of the test database and a transaction of another database keep VACUUM FULL from dropping the
    # filler rows. Neither locks hafd.contexts, so neither keeps hived from rewriting it.
    older_snapshot = session.bind.connect().execution_options(
        isolation_level="REPEATABLE READ"
    )
    older_snapshot_pid = older_snapshot.execute(
        text("SELECT pg_backend_pid()")
    ).scalar_one()
    other_database = create_engine(
        session.bind.url.set(database="postgres"), poolclass=NullPool
    ).connect()
    other_database_pid = other_database.execute(
        text("SELECT pg_backend_pid() FROM pg_current_xact_id()")
    ).scalar_one()

    # dead rows that only a rewrite gives back
    session.execute(
        text(
            "INSERT INTO hafd.contexts( name, schema, current_block_num, irreversible_block, owner, last_active_at, baseclass_id ) "
            "SELECT 'filler_' || i, repeat( 'x', 1000 ), 0, 0, 'compaction_filler', NOW(), 'hafd.contexts'::REGCLASS "
            "FROM generate_series( 1, 700 ) i"
        )
    )
    session.execute(text("DELETE FROM hafd.contexts WHERE owner = 'compaction_filler'"))
    deleted_by = session.execute(
        text("SELECT pg_current_xact_id()::xid::TEXT")
    ).scalar_one()
    session.commit()
    pages_before = heap_pages(session)
    assert pages_before > THRESHOLD_PAGES, (
        f"hafd.contexts has only {pages_before} pages"
    )

    try:
        # WHEN another session keeps a lock on the table
        with session.bind.connect() as holder:
            holder.execute(text("LOCK TABLE hafd.contexts IN ACCESS SHARE MODE"))
            head_while_held = node_under_test.get_last_block_number()

            # THEN hived skips the compaction, logs it, and keeps processing blocks
            wait_for_log_line(
                node_under_test,
                lambda line: (
                    "Compaction of hafd.contexts" in line and "skipped" in line
                ),
                "a skipped compaction of hafd.contexts",
            )
            node_under_test.wait_for_block_with_number(
                head_while_held + BLOCKS_WHILE_SKIPPING
            )
            assert heap_pages(session) >= pages_before, (
                "hafd.contexts was compacted while another session held a lock on it"
            )
            holders = older_snapshots(session, deleted_by)
            for pid in (older_snapshot_pid, other_database_pid):
                assert any(line.startswith(f"pid={pid},") for line in holders), (
                    f"session {pid}, older than the DELETE, is not reported: {holders}"
                )
            older_snapshot.close()
            other_database.close()
            # so the compaction that starts once the lock is gone can give the filler rows back
            wait_for_no_older_snapshots(session, deleted_by)
            holder.rollback()

        # WHEN the lock is gone THEN a later block compacts the table, with the application iterating
        compacted = wait_for_log_line(
            node_under_test,
            lambda line: "Compacted hafd.contexts from" in line,
            "a compaction of hafd.contexts",
        )
        tt.logger.info(compacted)
        pages_after = heap_pages(session)
        assert pages_after < THRESHOLD_PAGES, (
            f"hafd.contexts still has {pages_after} pages after: {compacted}"
        )
    finally:
        older_snapshot.close()
        other_database.close()
        session.execute(text("INSERT INTO compaction_app.stop VALUES ( TRUE )"))
        session.commit()
        app_thread.join(timeout=TIMEOUT_SECONDS)

    assert not app_thread.is_alive(), "the application loop did not stop"
    assert not app_errors, f"the application loop failed: {app_errors}"
    current_block = session.execute(
        text(
            "SELECT current_block_num FROM hafd.contexts WHERE name = 'compaction_app'"
        )
    ).scalar_one()
    assert current_block > 0, "the application processed no block"
