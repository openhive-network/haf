import time
from typing import Any, Tuple

from sqlalchemy import text
from sqlalchemy.orm import Session

import test_tools as tt


START_TEST_BLOCK = 115
# hived polls hafd.vacuum_requests every 10 seconds once it is in live sync
VACUUM_TIMEOUT_SECONDS = 180
# longer than the second hived waits for a lock before it skips a vacuum
PROBE_LOCK_TIMEOUT = "5s"


def request_statuses(session: Session) -> dict[str, str]:
    session.commit()
    return {
        kind: status
        for kind, status in session.execute(
            text(
                "SELECT kind, status::text FROM hafd.vacuum_requests WHERE schema_name = 'vacuum_locked' AND table_name = 'held'"
            )
        )
    }


def relfilenode(session: Session) -> int:
    return int(
        session.execute(
            text("SELECT pg_relation_filenode('vacuum_locked.held')")
        ).scalar_one()
    )


def wait_for_skipped_vacuum(node: Any) -> None:
    deadline = time.monotonic() + VACUUM_TIMEOUT_SECONDS
    while True:
        log: str = (node.directory / "stderr.log").read_text(errors="replace")
        if any(
            "Skipped VACUUM FULL ANALYZE" in line and "held" in line
            for line in log.splitlines()
        ):
            return
        assert time.monotonic() < deadline, (
            "hived never reported skipping the vacuum of the locked table"
        )
        time.sleep(1)


def test_vacuum_skips_locked_table(
    prepared_networks_and_database_12_8: Tuple[Any, Session],
) -> None:
    tt.logger.info("Start test_vacuum_skips_locked_table")

    # GIVEN
    networks_builder, session = prepared_networks_and_database_12_8
    node_under_test = networks_builder.networks[1].node("ApiNode0")
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)

    session.execute(text("CREATE SCHEMA vacuum_locked"))
    session.execute(text("CREATE TABLE vacuum_locked.held(id INTEGER, payload TEXT)"))
    session.execute(
        text(
            "INSERT INTO vacuum_locked.held SELECT i, md5(i::text) FROM generate_series(1, 10000) AS i"
        )
    )
    session.commit()
    filenode_before = relfilenode(session)

    with session.bind.connect() as holder:
        # an application in the middle of an iteration that writes the table
        holder.execute(text("LOCK TABLE vacuum_locked.held IN ROW EXCLUSIVE MODE"))

        # WHEN
        session.execute(
            text(
                "SELECT hive.app_request_table_vacuum('vacuum_locked', 'held', _kind => 'freeze')"
            )
        )
        session.execute(
            text("SELECT hive.app_request_table_vacuum('vacuum_locked', 'held')")
        )
        session.commit()

        # THEN
        wait_for_skipped_vacuum(node_under_test)
        assert request_statuses(session) == {
            "full": "requested",
            "freeze": "requested",
        }, (
            "a skipped 'full' must stay requested and keep the table's 'freeze' behind it"
        )

        # a VACUUM FULL still waiting for its lock would queue this read behind it
        session.execute(text(f"SET LOCAL lock_timeout = '{PROBE_LOCK_TIMEOUT}'"))
        assert (
            session.execute(
                text("SELECT count(*) FROM vacuum_locked.held")
            ).scalar_one()
            == 10000
        )
        session.commit()

        holder.rollback()

    deadline = time.monotonic() + VACUUM_TIMEOUT_SECONDS
    while (statuses := request_statuses(session)) != {
        "full": "vacuumed",
        "freeze": "vacuumed",
    }:
        assert "failed" not in statuses.values(), (
            f"vacuum of vacuum_locked.held failed: {statuses}"
        )
        assert time.monotonic() < deadline, (
            f"vacuum of vacuum_locked.held did not finish after the lock was released: {statuses}"
        )
        time.sleep(1)
    assert relfilenode(session) != filenode_before, (
        "'full' must rewrite the table once it is unlocked"
    )
