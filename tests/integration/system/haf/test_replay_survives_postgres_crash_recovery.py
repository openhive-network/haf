import glob
import os
import signal
import socket
import subprocess
import threading
import time
from pathlib import Path
from typing import Iterator, NamedTuple

import pytest
import sqlalchemy
from sqlalchemy import text
from sqlalchemy.pool import NullPool


from haf_local_tools.haf_node import HafNode
from haf_local_tools.system.haf import (
    assert_are_blocks_sync_with_haf_db,
    create_and_run_init_node_with_retry,
    prepare_and_send_transactions,
)

SCRIPTS_DIR = Path(__file__).resolve().parents[4] / "scripts"
LOCK_WAIT_TIMEOUT_SECONDS = 120
# hived's flush waits for this lock, held by an "application" whose backend the test kills
LOCKED_TABLE = "hafd.operations"
HIVED_WAITS_FOR_LOCK = (
    "SELECT count(*) FROM pg_locks l JOIN pg_stat_activity a ON a.pid = l.pid "
    f"WHERE l.relation = '{LOCKED_TABLE}'::regclass AND NOT l.granted AND a.usename = 'hived'"
)


class PrivatePostgres(NamedTuple):
    url: str
    log: Path


def postgres_bin_dir() -> Path:
    candidates = sorted(
        glob.glob("/usr/lib/postgresql/*/bin/initdb"),
        key=lambda path: int(Path(path).parts[-3]),
    )
    assert candidates, "no PostgreSQL server binaries under /usr/lib/postgresql"
    return Path(candidates[-1]).parent


def free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port: int = sock.getsockname()[1]
        return port


def create_haf_database(url: str) -> None:
    admin_engine = sqlalchemy.create_engine(
        url + "/postgres", poolclass=NullPool, isolation_level="AUTOCOMMIT"
    )
    with admin_engine.connect() as conn:
        conn.exec_driver_sql((SCRIPTS_DIR / "haf_builtin_roles.sql").read_text())
        conn.execute(
            text(
                "CREATE ROLE haf_admin WITH LOGIN SUPERUSER INHERIT CREATEDB NOCREATEROLE NOREPLICATION IN ROLE haf_administrators_group"
            )
        )
        conn.execute(
            text(
                "CREATE DATABASE haf_block_log WITH OWNER haf_admin ENCODING UTF8 LC_COLLATE 'C' LC_CTYPE 'C' TEMPLATE template0"
            )
        )
        conn.execute(
            text(
                "GRANT CREATE ON DATABASE haf_block_log TO hive_applications_owner_group"
            )
        )
    admin_engine.dispose()

    haf_engine = sqlalchemy.create_engine(
        url.replace("postgres@", "haf_admin@") + "/haf_block_log",
        poolclass=NullPool,
        isolation_level="AUTOCOMMIT",
    )
    with haf_engine.connect() as conn:
        conn.execute(text("CREATE EXTENSION hive_fork_manager CASCADE"))
    haf_engine.dispose()


@pytest.fixture
def private_postgres(tmp_path: Path) -> Iterator[PrivatePostgres]:
    """
    A PostgreSQL cluster of the test's own: killing a backend makes the postmaster end every session of its
    cluster and run crash recovery, which must not hit the tests running in parallel on the shared one.
    Its processes belong to the test's user, so the test can kill one.
    """
    bin_dir = postgres_bin_dir()
    data_dir = tmp_path / "pgdata"
    port = free_port()
    subprocess.run(
        [
            bin_dir / "initdb",
            "--pgdata",
            data_dir,
            "--username",
            "postgres",
            "--auth",
            "trust",
            "--encoding",
            "UTF8",
        ],
        check=True,
        capture_output=True,
    )
    options = f"-p {port} -k {tmp_path} -c listen_addresses=127.0.0.1 -c restart_after_crash=on"
    log = tmp_path / "postgres.log"
    subprocess.run(
        [
            bin_dir / "pg_ctl",
            "--pgdata",
            data_dir,
            "--log",
            log,
            "--options",
            options,
            "--wait",
            "start",
        ],
        check=True,
        capture_output=True,
    )
    try:
        url = f"postgresql://postgres@127.0.0.1:{port}"
        create_haf_database(url)
        yield PrivatePostgres(url, log)
    finally:
        subprocess.run(
            [bin_dir / "pg_ctl", "--pgdata", data_dir, "--mode", "immediate", "stop"],
            check=False,
        )


def kill_backend_when_hived_waits_for_lock(
    url: str, backend_pid: int, errors: list[Exception]
) -> None:
    try:
        engine = sqlalchemy.create_engine(
            url, poolclass=NullPool, isolation_level="AUTOCOMMIT"
        )
        deadline = time.monotonic() + LOCK_WAIT_TIMEOUT_SECONDS
        with engine.connect() as conn:
            while conn.execute(text(HIVED_WAITS_FOR_LOCK)).scalar_one() == 0:
                assert time.monotonic() < deadline, (
                    f"hived never waited for the lock on {LOCKED_TABLE}"
                )
                time.sleep(0.2)
        engine.dispose()
        os.kill(backend_pid, signal.SIGKILL)
    except Exception as error:  # handed to the test's thread, which re-raises it
        errors.append(error)


def test_replay_survives_postgres_crash_recovery(
    private_postgres: PrivatePostgres,
) -> None:
    """
    A backend of an application is killed with SIGKILL while hived's replay flush, one transaction that
    already copied the blocks, waits for the application's lock on hafd.operations. PostgreSQL ends every
    session and runs crash recovery; hived runs the lost transaction again from its start and keeps running,
    and the database holds every replayed block.
    """
    init_node = create_and_run_init_node_with_retry()
    transaction_0, transaction_1 = prepare_and_send_transactions(init_node)
    stop_block = transaction_1["block_num"]

    # the cluster is thrown away with the test
    haf_node = HafNode(
        database_url=private_postgres.url + "/haf_block_log", keep_database=True
    )
    # above the number of replayed blocks: the constraints stay, so the replay is flushed in a single transaction
    haf_node.config.psql_index_threshold = 100

    app_engine = sqlalchemy.create_engine(haf_node.database_url, poolclass=NullPool)
    app = app_engine.connect()
    app_pid = app.execute(text("SELECT pg_backend_pid()")).scalar_one()
    app.execute(text(f"LOCK TABLE {LOCKED_TABLE} IN SHARE MODE"))

    errors: list[Exception] = []
    killer = threading.Thread(
        target=kill_backend_when_hived_waits_for_lock,
        args=(haf_node.database_url, app_pid, errors),
    )
    killer.start()
    try:
        haf_node.run(
            replay_from=init_node.block_log,
            stop_at_block=stop_block,
            wait_for_live=False,
        )
    finally:
        killer.join()
        app.invalidate()
        app_engine.dispose()
    if errors:
        raise errors[0]

    haf_node.session.close()
    haf_node.wait_for_transaction_in_database(transaction_0, timeout=60)
    haf_node.wait_for_transaction_in_database(transaction_1, timeout=60)
    assert_are_blocks_sync_with_haf_db(haf_node, stop_block)
    assert haf_node.is_running()

    log = (haf_node.directory / "stderr.log").read_text(errors="replace")
    assert "in the middle of a transaction" in log
    assert "Running again, from its start, a transaction" in log
    assert "HAF is stopping synchronization" not in log
    haf_node.close()

    postgres_log = private_postgres.log.read_text(errors="replace")
    assert f"server process (PID {app_pid}) was terminated by signal 9" in postgres_log
    assert "all server processes terminated; reinitializing" in postgres_log
