import re
import threading
import time
from typing import Any, Tuple

from sqlalchemy import text
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session

import test_tools as tt


START_TEST_BLOCK = 115
# an application iteration that writes the table: one transaction every 5 seconds
ITERATION_SECONDS = 5
# hived waits 1 s, 2 s, 4 s and then 8 s for the lock, so the fourth attempt outlasts an iteration
# and gets the lock at its commit; each attempt follows a 10 s poll
MAX_SKIPS = 3
VACUUM_TIMEOUT_SECONDS = 120


def request_row(session: Session) -> Tuple[str, int, Any]:
    session.commit()
    status, skip_count, first_skip_time = session.execute(
        text(
            "SELECT status::text, skip_count, first_skip_time FROM hafd.vacuum_requests "
            "WHERE schema_name = 'vacuum_escalated' AND table_name = 'held' AND kind = 'full'"
        )
    ).one()
    return status, skip_count, first_skip_time


def relfilenode(session: Session) -> int:
    return int(
        session.execute(
            text("SELECT pg_relation_filenode('vacuum_escalated.held')")
        ).scalar_one()
    )


def run_iterations(engine: Engine, stop: threading.Event) -> None:
    with engine.connect() as conn:
        while not stop.is_set():
            conn.execute(text("LOCK TABLE vacuum_escalated.held IN ROW EXCLUSIVE MODE"))
            time.sleep(ITERATION_SECONDS)
            conn.commit()


def skips_before_vacuum(node: Any) -> int:
    log: str = (node.directory / "stderr.log").read_text(errors="replace")
    found = re.findall(
        r"Vacuumed table: vacuum_escalated\.held in \d+ seconds, after (\d+) skips",
        log,
    )
    assert len(found) == 1, (
        f"hived should log the skips of the vacuum once, found: {found}"
    )
    return int(found[0])


def test_vacuum_request_escalates_lock_wait(
    prepared_networks_and_database_12_8: Tuple[Any, Session],
) -> None:
    tt.logger.info("Start test_vacuum_request_escalates_lock_wait")

    # GIVEN
    networks_builder, session = prepared_networks_and_database_12_8
    node_under_test = networks_builder.networks[1].node("ApiNode0")
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)

    session.execute(text("CREATE SCHEMA vacuum_escalated"))
    session.execute(
        text("CREATE TABLE vacuum_escalated.held(id INTEGER, payload TEXT)")
    )
    session.execute(
        text(
            "INSERT INTO vacuum_escalated.held SELECT i, md5(i::text) FROM generate_series(1, 10000) AS i"
        )
    )
    session.commit()
    filenode_before = relfilenode(session)

    stop = threading.Event()
    application = threading.Thread(
        target=run_iterations, args=(session.bind, stop), daemon=True
    )
    application.start()
    try:
        # WHEN
        session.execute(
            text("SELECT hive.app_request_table_vacuum('vacuum_escalated', 'held')")
        )
        session.commit()

        # THEN
        deadline = time.monotonic() + VACUUM_TIMEOUT_SECONDS
        while (row := request_row(session))[0] != "vacuumed":
            assert row[0] == "requested", f"vacuum of vacuum_escalated.held: {row}"
            assert time.monotonic() < deadline, (
                f"a table locked by 5 s transactions was not vacuumed within {VACUUM_TIMEOUT_SECONDS} s: {row}"
            )
            time.sleep(1)
    finally:
        stop.set()
        application.join(timeout=3 * ITERATION_SECONDS)

    assert row[1:] == (0, None), (
        f"a vacuumed request must have its skips cleared: {row}"
    )
    assert relfilenode(session) != filenode_before, "'full' must rewrite the table"
    assert skips_before_vacuum(node_under_test) <= MAX_SKIPS
