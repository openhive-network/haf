from __future__ import annotations

import os
import subprocess
from pathlib import Path
from typing import TYPE_CHECKING, Final

import pytest

import test_tools as tt
import sqlalchemy
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import NullPool


from test_tools.__private import paths_to_executables
from haf_local_tools import query_all

from shared_tools.complex_networks import create_block_log_directory_name

if TYPE_CHECKING:
    from sqlalchemy.orm.session import Session


SQL_TABLE_COUNT: Final[str] = """
SELECT COUNT(*)
FROM hive.{table};
"""

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
    def test_dump_load_instance_scripts(self, prepared_networks_and_database_1, database, first_run : int, dump_exit_before_sync : int, dump_stop_replay_at_block : int, load_exit_before_sync : int, load_stop_replay_at_block : int, after_dump : int, after_load : int):
        # GIVEN
        self.run_node_with_db(prepared_networks_and_database_1, database, first_run)
        

        # WHEN
        additional_dump_command_line = self.generate_additional_command_line(dump_exit_before_sync, dump_stop_replay_at_block)
        self.dump_instance(additional_dump_command_line)
        self.assert_dumped(after_dump)
        
        additional_load_command_line = self.generate_additional_command_line(load_exit_before_sync, load_stop_replay_at_block)
        self.load_instance(additional_load_command_line)

        # THEN
        self.assert_loaded(after_load)
        

    def run_node_with_db(self, prepared_networks_and_database_1, database, stop_at_block : int):
        node, session, self.db_name = prepared_networks_and_database_1(database)

        self.hived_executable_path =paths_to_executables.get_path_of("hived")


        self.hived_data_dir=node.directory
        self.backup_dir = self.hived_data_dir/'backup'


        scripts_path=Path(os.getenv('SETUP_SCRIPTS_PATH'))
        

        self.dump_instance_script=scripts_path/'dump_instance.sh'
        self.load_instance_script=scripts_path/'load_instance.sh'

        node.run(replay_from=create_block_log_directory_name("block_log") / "block_log", stop_at_block=stop_at_block, exit_before_synchronization=True)
        session.close()


    def dump_instance(self, additional_command_line : str):
        command = f"{self.dump_instance_script} \
        --backup-dir={self.backup_dir} \
        --hived-executable-path={self.hived_executable_path} \
        --hived-data-dir={self.hived_data_dir} \
        --haf-db-name={self.db_name.database} \
        --override-existing-backup-dir \
        {additional_command_line}"

        shell(command)

    def assert_dumped(self, at_block : int):
        session = create_session(self.db_name)
        assert query_count(session, 'blocks') == at_block
        session.close()

    def load_instance(self, additional_command_line : str):
        command = f"{self.load_instance_script} \
        --backup-dir={self.backup_dir} \
        --hived-executable-path={self.hived_executable_path} \
        --hived-data-dir={self.hived_data_dir} \
        --haf-db-name={self.db_name.database} \
        {additional_command_line}"

        shell(command)

    def assert_loaded(self, after_load : int):
        session = create_session(self.db_name)
        assert query_count(session, 'blocks') == after_load
        session.close()

    @staticmethod
    def generate_additional_command_line(dump_exit_before_sync : bool, dump_stop_replay_at_block : bool) -> str:
        additional_command_line = ''
        if dump_exit_before_sync:
            additional_command_line+=' --exit-before-sync'
        if dump_stop_replay_at_block:
            additional_command_line+=f' --stop-replay-at-block={dump_stop_replay_at_block}'
        return additional_command_line

def shell(command: str) -> None:
    subprocess.call(command, shell=True)

def query_count(session, table):
    sql_raw = SQL_TABLE_COUNT.format(table=table)
    count = query_all(session, sql_raw)
    return count[0][0]

def create_session(url: str) -> Session:
    engine = sqlalchemy.create_engine(url, echo=False, poolclass=NullPool)
    Session = sessionmaker(bind=engine)
    session = Session()
    return session
