import time
from typing import Any, Tuple

from sqlalchemy import text
from sqlalchemy.orm import Session

import test_tools as tt


START_TEST_BLOCK = 115
# hived polls hafd.vacuum_requests every 10 seconds once it is in live sync
VACUUM_TIMEOUT_SECONDS = 180


def create_insert_only_table(session: Session, name: str) -> None:
    # autovacuum would build the visibility map on its own and hide what the requests did
    session.execute(text(f"CREATE TABLE vacuum_kinds.{name}(id INTEGER, payload TEXT) WITH (autovacuum_enabled = false)"))
    session.execute(text(f"INSERT INTO vacuum_kinds.{name} SELECT i, md5(i::text) FROM generate_series(1, 50000) AS i"))


def relfilenode(session: Session, name: str) -> int:
    return int(session.execute(text(f"SELECT pg_relation_filenode('vacuum_kinds.{name}')")).scalar_one())


def wait_until_vacuumed(session: Session, name: str, kinds: list[str]) -> None:
    deadline = time.monotonic() + VACUUM_TIMEOUT_SECONDS
    while True:
        session.commit()
        rows: dict[str, str] = {kind: status for kind, status in session.execute(text(
            "SELECT kind, status::text FROM hafd.vacuum_requests WHERE schema_name = 'vacuum_kinds' AND table_name = :name"
        ), {"name": name})}
        assert 'failed' not in rows.values(), f'vacuum of vacuum_kinds.{name} failed: {rows}'
        if all(rows.get(kind) == 'vacuumed' for kind in kinds):
            return
        assert time.monotonic() < deadline, f'vacuum of vacuum_kinds.{name} did not finish: {rows}'
        time.sleep(1)


def test_vacuum_request_kinds(prepared_networks_and_database_12_8: Tuple[Any, Session]) -> None:
    tt.logger.info('Start test_vacuum_request_kinds')

    # GIVEN
    networks_builder, session = prepared_networks_and_database_12_8
    node_under_test = networks_builder.networks[1].node('ApiNode0')
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)

    session.execute(text("CREATE SCHEMA vacuum_kinds"))
    create_insert_only_table(session, 'online')
    create_insert_only_table(session, 'rewritten')
    session.commit()
    online_filenode = relfilenode(session, 'online')
    rewritten_filenode = relfilenode(session, 'rewritten')

    # WHEN
    session.execute(text("SELECT hive.app_request_table_vacuum('vacuum_kinds', 'online', _kind => 'analyze')"))
    session.execute(text("SELECT hive.app_request_table_vacuum('vacuum_kinds.online', _kind => 'vacuum')"))
    # both in one transaction, so hived sees the pair together and must order 'full' first
    session.execute(text("SELECT hive.app_request_table_vacuum('vacuum_kinds', 'rewritten', _kind => 'freeze')"))
    session.execute(text("SELECT hive.app_request_table_vacuum('vacuum_kinds', 'rewritten')"))
    session.commit()

    wait_until_vacuumed(session, 'online', ['analyze', 'vacuum'])
    wait_until_vacuumed(session, 'rewritten', ['full', 'freeze'])

    # THEN
    assert relfilenode(session, 'online') == online_filenode, "'vacuum' and 'analyze' must not rewrite the table"
    assert relfilenode(session, 'rewritten') != rewritten_filenode, "'full' must rewrite the table"

    relpages, relallvisible, vm_size = session.execute(text(
        "SELECT relpages, relallvisible, pg_relation_size(oid, 'vm') FROM pg_class WHERE oid = 'vacuum_kinds.rewritten'::regclass"
    )).one()
    tt.logger.info(f'vacuum_kinds.rewritten: relpages={relpages} relallvisible={relallvisible} vm_size={vm_size}')
    assert relpages > 0
    # an old snapshot held elsewhere at vacuum time can keep a few pages from becoming all-visible
    assert relallvisible >= 0.95 * relpages, "'freeze' must run after 'full' and leave the table all-visible"
    assert vm_size > 0, "'freeze' must leave the table with a visibility map"
