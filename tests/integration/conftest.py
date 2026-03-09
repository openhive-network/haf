import os
from datetime import timedelta
from pathlib import Path
from typing import Any, Tuple, Iterable
from random import randbytes
from functools import partial

import pytest
import sqlalchemy
from sqlalchemy_utils import database_exists, create_database, drop_database
from sqlalchemy.ext.automap import automap_base
from sqlalchemy.orm import sessionmaker, close_all_sessions
from sqlalchemy.pool import NullPool

from test_tools.__private.scope.scope_fixtures import *  # pylint: disable=wildcard-import, unused-wildcard-import
from test_tools.__private.user_handles.get_implementation import get_implementation
from test_tools.__private.node import Node
import test_tools as tt

from test_tools import complex_networks as ttcn
from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround

class SQLNodesPreparer(ttcn.NodesPreparer):
    def __init__(self, database, start_block=1) -> None:
        self.sessions = []
        self.database = database
        self.start_block = start_block

    def prepare(self, builder: ttcn.NetworksBuilder):
        for cnt, node in enumerate(builder.prepare_nodes):
            DB_URL = os.getenv("DB_URL")
            self.sessions.append( self.database(f"{DB_URL}-{cnt}") )

            node.config.plugin.append('sql_serializer')
            node.config.psql_url = str(self.db_url(cnt))
            node.config.psql_first_block = self.start_block
            apply_block_log_type_to_monolithic_workaround(node)

            # Increase initialization timeout for nodes with sql_serializer.
            # Under CI load with parallel tests, the default 5-second beekeepy timeout
            # is insufficient for port detection. This matches HafNode behavior.
            node_impl = get_implementation(node, Node)
            with node_impl.update_settings() as settings:
                settings.initialization_timeout = timedelta(seconds=30)

        for node in builder.nodes:
            apply_block_log_type_to_monolithic_workaround(node)
            node.config.log_logger = '{"name":"default","level":"debug","appender":"stderr,p2p"} '\
                                    '{"name":"user","level":"debug","appender":"stderr,p2p"} '\
                                    '{"name":"chainlock","level":"debug","appender":"p2p"} '\
                                    '{"name":"sync","level":"debug","appender":"p2p"} '\
                                    '{"name":"p2p","level":"debug","appender":"p2p"}'


    def db_url(self, idx) -> Any:
        assert idx < len(self.sessions)
        return None if self.sessions[idx] is None else self.sessions[idx].get_bind().url


    def node(self, builder, idx) -> Any:
        assert idx < len(builder.nodes)
        return builder.nodes[idx]


from test_tools.__private.process.node_config import NodeConfig

# Track which NodeConfig instances need psql-lite-mode appended to config.ini.
# msgspec.Struct blocks all non-field attribute assignment on instances (even via
# object.__setattr__), so we patch NodeConfig.save at the CLASS level and use this
# set of instance ids to selectively append the flag.
_lite_mode_config_ids: set = set()
_original_node_config_save = NodeConfig.save

def _save_with_lite_mode(self, directory):
    _original_node_config_save(self, directory)
    if id(self) in _lite_mode_config_ids:
        config_path = Path(directory) / "config.ini"
        if config_path.exists():
            with open(config_path, "a") as f:
                f.write("\npsql-lite-mode = 1\n")

NodeConfig.save = _save_with_lite_mode


class LiteModeSQLNodesPreparer(SQLNodesPreparer):
    """SQLNodesPreparer that enables --psql-lite-mode on the hived node."""
    def prepare(self, builder: ttcn.NetworksBuilder):
        super().prepare(builder)
        for node in builder.prepare_nodes:
            _lite_mode_config_ids.add(id(node.config))


def prepare_network_with_1_session(database, architecture: ttcn.NetworksArchitecture, block_log_directory_name: Path = None, time_offsets: Iterable[int] = None) -> Tuple[ttcn.NetworksBuilder, Any]:
    preparer = SQLNodesPreparer(database)
    return ttcn.run_whole_network(architecture, block_log_directory_name, time_offsets, preparer), preparer.sessions[0]


def prepare_network_with_1_session_lite_mode(database, architecture: ttcn.NetworksArchitecture, block_log_directory_name: Path = None, time_offsets: Iterable[int] = None) -> Tuple[ttcn.NetworksBuilder, Any]:
    preparer = LiteModeSQLNodesPreparer(database)
    return ttcn.run_whole_network(architecture, block_log_directory_name, time_offsets, preparer), preparer.sessions[0]

def prepare_network_with_1_session_from_115(database, architecture: ttcn.NetworksArchitecture, block_log_directory_name: Path = None, time_offsets: Iterable[int] = None) -> Tuple[ttcn.NetworksBuilder, Any]:
    preparer = SQLNodesPreparer(database, 115)
    return ttcn.run_whole_network(architecture, block_log_directory_name, time_offsets, preparer), preparer.sessions[0]


def prepare_network_with_2_sessions(database, architecture: ttcn.NetworksArchitecture, block_log_directory_name: Path = None, time_offsets: Iterable[int] = None) -> Tuple[ttcn.NetworksBuilder, Any]:
    preparer = SQLNodesPreparer(database)
    return ttcn.run_whole_network(architecture, block_log_directory_name, time_offsets, preparer), preparer.sessions


@pytest.fixture()
def database():
    """
    Returns factory function that creates database with parametrized name and extension hive_fork_manager installed
    """

    def make_database(url):
        url = url + '_' + randbytes(8).hex()
        tt.logger.info(f'Preparing database {url}')
        if database_exists(url):
            drop_database(url)
        create_database(url, template="haf_block_log")

        engine = sqlalchemy.create_engine(url, echo=False, poolclass=NullPool)

        Session = sessionmaker(bind=engine)
        session = Session()

        return session

    yield make_database

    close_all_sessions()


@pytest.fixture()
def prepared_networks_and_database_12_8(database) -> Tuple[ttcn.NetworksBuilder, Any]:
    config = {
        "networks": [
                        {
                            "InitNode"     : True,
                            "WitnessNodes" :[12]
                        },
                        {
                            "ApiNode"      : { "Active": True, "Prepare": True },
                            "WitnessNodes" :[8]
                        }
                    ]
    }
    architecture = ttcn.NetworksArchitecture()
    architecture.load(config)
    yield prepare_network_with_1_session(database, architecture, ttcn.create_block_log_directory_name('block_log_12_8'), None)

@pytest.fixture()
def prepared_networks_and_database_12_8_lite_mode(database) -> Tuple[ttcn.NetworksBuilder, Any]:
    config = {
        "networks": [
                        {
                            "InitNode"     : True,
                            "WitnessNodes" :[12]
                        },
                        {
                            "ApiNode"      : { "Active": True, "Prepare": True },
                            "WitnessNodes" :[8]
                        }
                    ]
    }
    architecture = ttcn.NetworksArchitecture()
    architecture.load(config)
    yield prepare_network_with_1_session_lite_mode(database, architecture, ttcn.create_block_log_directory_name('block_log_12_8'), None)

@pytest.fixture()
def prepared_networks_and_database_12_8_from_115(database) -> Tuple[ttcn.NetworksBuilder, Any]:
    config = {
        "networks": [
            {
                "InitNode"     : True,
                "WitnessNodes" :[12]
            },
            {
                "ApiNode"      : { "Active": True, "Prepare": True },
                "WitnessNodes" :[8]
            }
        ]
    }
    architecture = ttcn.NetworksArchitecture()
    architecture.load(config)
    yield prepare_network_with_1_session_from_115(database, architecture, ttcn.create_block_log_directory_name('block_log_12_8'), None)

@pytest.fixture()
def prepared_networks_and_database_12_8_with_2_sessions(database) -> Tuple[ttcn.NetworksBuilder, Any]:
    config = {
        "networks": [
                        {
                            "InitNode"     : True,
                            "ApiNode"      : { "Active": True, "Prepare": True },
                            "WitnessNodes" :[12]
                        },
                        {
                            "ApiNode"      : { "Active": True, "Prepare": True },
                            "WitnessNodes" :[8]
                        }
                    ]
    }
    architecture = ttcn.NetworksArchitecture()
    architecture.load(config)
    yield prepare_network_with_2_sessions(database, architecture, ttcn.create_block_log_directory_name('block_log_12_8'), None)


@pytest.fixture()
def prepared_networks_and_database_12_8_without_block_log(database) -> Tuple[ttcn.NetworksBuilder, Any]:
    config = {
        "networks": [
                        {
                            "InitNode"     : True,
                            "WitnessNodes" :[12]
                        },
                        {
                            "ApiNode"      : { "Active": True, "Prepare": True },
                            "WitnessNodes" :[8]
                        }
                    ]
    }
    architecture = ttcn.NetworksArchitecture()
    architecture.load(config)
    yield prepare_network_with_1_session(database, architecture, None, None)


@pytest.fixture()
def prepared_networks_and_database_17_3(database) -> Tuple[ttcn.NetworksBuilder, Any]:
    config = {
        "networks": [
                        {
                            "InitNode"     : True,
                            "ApiNode"      : True,
                            "WitnessNodes" :[17]
                        },
                        {
                            "ApiNode"      : { "Active": True, "Prepare": True },
                            "WitnessNodes" :[3]
                        }
                    ]
    }
    architecture = ttcn.NetworksArchitecture()
    architecture.load(config)
    yield prepare_network_with_1_session(database, architecture, ttcn.create_block_log_directory_name('block_log_17_3'), None)


@pytest.fixture()
def prepared_networks_and_database_4_4_4_4_4(database) -> Tuple[ttcn.NetworksBuilder, Any]:
    config = {
        "networks": [
                        {
                            "InitNode"     : True,
                            "WitnessNodes" :[4]
                        },
                        {
                            "ApiNode"      : { "Active": True, "Prepare": True },
                            "WitnessNodes" :[4]
                        },
                        {
                            "WitnessNodes" :[4]
                        },
                        {
                            "WitnessNodes" :[4]
                        },
                        {
                            "WitnessNodes" :[4]
                        }
                    ]
    }
    architecture = ttcn.NetworksArchitecture()
    architecture.load(config)
    time_offsets = ttcn.prepare_time_offsets(architecture.nodes_number)

    yield prepare_network_with_1_session(database, architecture, ttcn.create_block_log_directory_name('block_log_4_4_4_4_4'), time_offsets)


@pytest.fixture()
def prepared_networks_and_database_1() -> Tuple[tt.ApiNode, Any, Any]:

    def make_network(database) -> Tuple[tt.ApiNode, Any, Any]:
        config = {
            "networks": [
                            {
                                "ApiNode"   : { "Active": True, "Prepare": True },
                            }
                        ]
        }
        architecture = ttcn.NetworksArchitecture()
        architecture.load(config)

        builder = ttcn.NetworksBuilder()
        builder.build(architecture, True)

        preparer = SQLNodesPreparer(database)
        preparer.prepare(builder)

        return preparer.node(builder, 0), preparer.sessions[0], preparer.db_url(0)

    yield make_network

@pytest.fixture()
def prepared_networks_and_database_12_8_from_60(database) -> Tuple[ttcn.NetworksBuilder, Any]:
    config = {
        "networks": [
            {
                "InitNode"     : True,
                "WitnessNodes" :[12]
            },
            {
                "ApiNode"      : { "Active": True, "Prepare": True },
                "WitnessNodes" :[8]
            }
        ]
    }
    architecture = ttcn.NetworksArchitecture()
    architecture.load(config)
    yield prepare_network_with_1_session(database, architecture, ttcn.create_block_log_directory_name('block_log_12_8'), None)
