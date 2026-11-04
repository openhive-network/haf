from __future__ import annotations

import os
import re
import signal
import subprocess
from pathlib import Path
from typing import TYPE_CHECKING, Final

import pytest

import test_tools as tt
import sqlalchemy
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import NullPool


from test_tools.__private import paths_to_executables
from haf_local_tools import get_head_block, get_irreversible_block, query_all

from test_tools import complex_networks as ttcn

if TYPE_CHECKING:
    from sqlalchemy.orm.session import Session


SQL_TABLE_COUNT: Final[str] = """
SELECT COUNT(*)
FROM hafd.{table};
"""

SQL_MAX_BLOCK_NUM: Final[str] = """
SELECT COALESCE(MAX(num), 0)
FROM hafd.{table};
"""

LIVE_SYNC_START_BLOCK: Final[int] = 110
REVERSIBLE_BLOCKS_BEFORE_STOP: Final[int] = 5
IRREVERSIBLE_BLOCKS_AHEAD_OF_HAF: Final[int] = 3

DUMP_REFUSAL: Final[re.Pattern[str]] = re.compile(
    r"hived's state is at its last irreversible block (\d+), but HAF's irreversible head block is (\d+)"
)

class Test:
    @pytest.mark.parametrize(
        'dump_exit_before_sync' , [
            0,
            1
        ]
    )
    @pytest.mark.parametrize(
        'load_exit_before_sync' , [
            # 0,
            1 # has to be set -  not to timeout
        ]
    )
    @pytest.mark.parametrize(
        'first_run, dump_stop_replay_at_block, load_stop_replay_at_block, after_dump, after_load', [
        ##########################################################
          (30,          0,                       50                         , 30,         50),
          (30,         40,                       50                         , 30,         50),
          (35,          0,                       50                         , 35,         50),
          (30,          0,                        0                         , 30,        105),
          (30,          0,                        0,                          30,        105),
          (30,         30,                        0,                          30,        105),
          (30,         30,                       30,                          30,         30),
          (30,         31,                       31,                          30,         31),
          (30,         31,                       40,                          30,         40),
          (30,         40,                       40,                          30,         40),
          (30,         40,                       41,                          30,         41),
          (30,         40,                       50,                          30,         50),

        ]
    )
    def test_dump_load_instance_scripts(self, prepared_networks_and_database_1, database, first_run : int, dump_exit_before_sync : bool, dump_stop_replay_at_block : int, load_exit_before_sync : bool, load_stop_replay_at_block : int, after_dump : int, after_load : int) -> None:
        # GIVEN
        self.run_node_with_db(prepared_networks_and_database_1, database, first_run)
        
        # Generate all logs into exclusive test directory.
        os.chdir(tt.context.get_current_directory())

        # WHEN
        additional_dump_command_line = self.generate_additional_command_line(dump_exit_before_sync, dump_stop_replay_at_block)

        tt.logger.info(f"Generated additonal dump command line: {additional_dump_command_line}")

        self.dump_instance(additional_dump_command_line)
        self.assert_dumped(after_dump)
        
        additional_load_command_line = self.generate_additional_command_line(load_exit_before_sync, load_stop_replay_at_block)
        self.load_instance(additional_load_command_line)

        # THEN
        self.assert_loaded(after_load)
        

    def test_dump_load_instance_scripts_live_synced(self, prepared_networks_and_database_12_8: tuple[ttcn.NetworksBuilder, Session]) -> None:
        # GIVEN
        networks_builder, session = prepared_networks_and_database_12_8
        self.db_url = session.get_bind().url
        node_under_test = networks_builder.networks[1].node('ApiNode0')
        node_under_test.wait_for_block_with_number(LIVE_SYNC_START_BLOCK)

        # Without the 8 witnesses of WitnessNode1 the rest stay below the irreversibility threshold,
        # so the node under test keeps receiving reversible blocks above a stalled irreversible head.
        networks_builder.networks[1].node('WitnessNode1').close()
        irreversible_block = get_irreversible_block(node_under_test)
        node_under_test.wait_for_block_with_number(irreversible_block + REVERSIBLE_BLOCKS_BEFORE_STOP)
        hived_head_block = get_head_block(node_under_test)

        for node in networks_builder.nodes:
            node.close()
        session.close()

        session = create_session(self.db_url)
        haf_head_block = query_max_block_num(session, 'blocks')
        assert query_max_block_num(session, 'blocks_reversible') > haf_head_block
        session.close()
        assert hived_head_block > haf_head_block
        tt.logger.info(f"Stopped with hived head block {hived_head_block} and HAF head block {haf_head_block}")

        self.use_node_data_dir(node_under_test.directory)
        os.chdir(tt.context.get_current_directory())

        # WHEN
        self.dump_instance('')
        self.assert_dumped(haf_head_block)
        self.load_instance(self.generate_additional_command_line(True, 0))

        # THEN
        self.assert_loaded(haf_head_block)

    def test_dump_instance_refuses_after_hived_killed(self, prepared_networks_and_database_12_8: tuple[ttcn.NetworksBuilder, Session]) -> None:
        # GIVEN
        networks_builder, session = prepared_networks_and_database_12_8
        self.db_url = session.get_bind().url
        node_under_test = networks_builder.networks[1].node('ApiNode0')
        node_under_test.wait_for_block_with_number(LIVE_SYNC_START_BLOCK)

        # The lock stalls sql_serializer's hive.set_irreversible while hived keeps applying blocks and
        # queues them in its write-ahead log, so the kill leaves hived's LIB above HAF's irreversible head.
        blocker = create_session(self.db_url)
        blocker.execute(sqlalchemy.text("LOCK TABLE hafd.blocks IN SHARE MODE"))
        haf_head_block = query_max_block_num(blocker, 'blocks')
        tt.Time.wait_for(
            lambda: get_irreversible_block(node_under_test) >= haf_head_block + IRREVERSIBLE_BLOCKS_AHEAD_OF_HAF,
            timeout=120,
        )
        hived_irreversible_block = get_irreversible_block(node_under_test)

        os.kill(hived_pid(node_under_test.directory), signal.SIGKILL)
        tt.Time.wait_for(lambda: not node_under_test.is_running(), timeout=30)
        # The killed hived's backend still waits for the lock; once granted it would move blocks to hafd.blocks.
        blocker.execute(sqlalchemy.text(
            "SELECT pg_terminate_backend(pid) FROM pg_stat_activity "
            "WHERE datname = current_database() AND wait_event_type = 'Lock'"
        ))
        blocker.rollback()
        blocker.close()
        for node in networks_builder.nodes:
            node.close()
        session.close()

        session = create_session(self.db_url)
        assert query_max_block_num(session, 'blocks') == haf_head_block
        session.close()
        tt.logger.info(f"Killed hived at irreversible block {hived_irreversible_block} or later, HAF head block {haf_head_block}")

        self.use_node_data_dir(node_under_test.directory)
        os.chdir(tt.context.get_current_directory())

        # WHEN
        with pytest.raises(subprocess.CalledProcessError):
            self.dump_instance('')

        # THEN
        refusal = DUMP_REFUSAL.search(Path('dump_instance.log').read_text(errors='replace'))
        assert refusal is not None, "dump_instance.sh did not report the mismatch of hived's LIB and HAF's head"
        assert int(refusal.group(1)) >= hived_irreversible_block
        assert int(refusal.group(2)) == haf_head_block
        assert not (self.backup_dir / 'hived').exists()
        assert not (self.backup_dir / 'db').exists()

    def run_node_with_db(self, prepared_networks_and_database_1, database, stop_at_block : int) -> None:
        node, session, self.db_url = prepared_networks_and_database_1(database)
        self.use_node_data_dir(node.directory)

        node.run(replay_from=ttcn.create_block_log_directory_name("block_log"), stop_at_block=stop_at_block, exit_before_synchronization=True)
        session.close()

    def use_node_data_dir(self, data_dir: Path) -> None:
        self.hived_executable_path =paths_to_executables.get_path_of("hived")


        self.hived_data_dir=data_dir
        self.backup_dir = self.hived_data_dir/'backup'


        scripts_path=Path(os.environ['SETUP_SCRIPTS_PATH'])
        

        self.dump_instance_script=scripts_path/'dump_instance.sh'
        self.load_instance_script=scripts_path/'load_instance.sh'


    def dump_instance(self, additional_command_line : str) -> None:
        command = f"{self.dump_instance_script} \
        --backup-dir={self.backup_dir} \
        --hived-executable-path={self.hived_executable_path} \
        --hived-data-dir={self.hived_data_dir} \
        --haf-db-admin={self.db_url.username} \
        --haf-db-host={self.db_url.host} \
        --haf-db-port={self.db_url.port} \
        --haf-db-name={self.db_url.database} \
        --override-existing-backup-dir \
        {additional_command_line}"

        tt.logger.info(f"Attempting to execute command: `{command}'")
        shell(command)

    def assert_dumped(self, at_block : int) -> None:
        session = create_session(self.db_url)
        assert query_count(session, 'blocks') == at_block
        session.close()

    def load_instance(self, additional_command_line : str) -> None:
        command = f"{self.load_instance_script} \
        --backup-dir={self.backup_dir} \
        --hived-executable-path={self.hived_executable_path} \
        --hived-data-dir={self.hived_data_dir} \
        --haf-db-admin={self.db_url.username} \
        --haf-db-host={self.db_url.host} \
        --haf-db-port={self.db_url.port} \
        --haf-db-name={self.db_url.database} \
        {additional_command_line}"

        tt.logger.info(f"Attempting to execute command: `{command}'")
        shell(command)

    def assert_loaded(self, after_load : int) -> None:
        session = create_session(self.db_url)
        assert query_count(session, 'blocks') == after_load
        session.close()

    @staticmethod
    def generate_additional_command_line(dump_exit_before_sync : bool, dump_stop_replay_at_block : int) -> str:
        additional_command_line = ''
        if dump_exit_before_sync:
            additional_command_line+=' --exit-before-sync'
        if dump_stop_replay_at_block:
            additional_command_line+=f' --stop-at-block={dump_stop_replay_at_block}'
        return additional_command_line

def hived_pid(data_dir: Path) -> int:
    """The pid of the hived process running on data_dir (test_tools keeps its process private)."""
    pids = []
    for proc in Path("/proc").iterdir():
        if not proc.name.isdigit():
            continue
        try:
            cmdline = (proc / "cmdline").read_bytes().split(b"\0")
        except (FileNotFoundError, ProcessLookupError, PermissionError):
            continue
        if Path(cmdline[0].decode()).name == "hived" and str(data_dir).encode() in cmdline:
            pids.append(int(proc.name))
    assert len(pids) == 1, f"expected one hived on {data_dir}, found pids {pids}"
    return pids[0]

def shell(command: str) -> None:
    subprocess.check_call(command, shell=True)

def query_count(session, table):
    sql_raw = SQL_TABLE_COUNT.format(table=table)
    count = query_all(session, sql_raw)
    return count[0][0]

def query_max_block_num(session: Session, table: str) -> int:
    return int(query_all(session, SQL_MAX_BLOCK_NUM.format(table=table))[0][0])

def create_session(url: str) -> Session:
    engine = sqlalchemy.create_engine(url, echo=False, poolclass=NullPool)
    Session = sessionmaker(bind=engine)
    session = Session()
    return session
