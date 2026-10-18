import time
from typing import Any, Tuple

from sqlalchemy import text
from sqlalchemy.orm import Session

import test_tools as tt

from haf_local_tools import get_irreversible_block, wait_for_irreversible_in_database


START_TEST_BLOCK = 115
# hived polls every 10 seconds and first retries a lost connection after 1 second
RECONNECT_TIMEOUT_SECONDS = 120
MONITOR_BACKENDS = (
    "FROM pg_stat_activity "
    "WHERE datname = current_database() AND usename = 'haf_maintainer' AND application_name = 'hived_index'"
)


def wait_for_monitor_backend(session: Session) -> None:
    deadline = time.monotonic() + RECONNECT_TIMEOUT_SECONDS
    while True:
        session.commit()
        if session.execute(text(f"SELECT count(*) {MONITOR_BACKENDS}")).scalar_one() > 0:
            return
        assert time.monotonic() < deadline, "the index monitor never connected to the database"
        time.sleep(1)


def wait_for_log_line(node: Any, line: str) -> str:
    deadline = time.monotonic() + RECONNECT_TIMEOUT_SECONDS
    while True:
        log: str = (node.directory / "stderr.log").read_text(errors="replace")
        if line in log:
            return log
        assert time.monotonic() < deadline, f"'{line}' did not appear in the hived log"
        time.sleep(1)


def test_index_monitor_reconnect(prepared_networks_and_database_12_8: Tuple[Any, Session]) -> None:
    tt.logger.info('Start test_index_monitor_reconnect')

    # GIVEN
    networks_builder, session = prepared_networks_and_database_12_8
    node_under_test = networks_builder.networks[1].node('ApiNode0')
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    wait_for_monitor_backend(session)

    # WHEN
    terminated = session.execute(text(f"SELECT count(*) FILTER (WHERE pg_terminate_backend(pid)) {MONITOR_BACKENDS}")).scalar_one()
    session.commit()
    assert terminated > 0
    irreversible_at_termination = get_irreversible_block(node_under_test)

    # THEN
    log = wait_for_log_line(node_under_test, "Index monitor reconnected to the database")
    assert "Index monitor has no usable database connection" in log
    wait_for_irreversible_in_database(session, irreversible_at_termination + 3, timeout=float(RECONNECT_TIMEOUT_SECONDS))
    assert node_under_test.is_running()
    log = (node_under_test.directory / "stderr.log").read_text(errors="replace")
    assert "Fatal error in poll_and_create_indexes thread" not in log
