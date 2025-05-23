import os
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
import test_tools as tt

import shared_tools.networks_architecture as networks
from shared_tools.complex_networks import NodesPreparer, run_whole_network, prepare_time_offsets, create_block_log_directory_name
from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround

class SQLNodesPreparer(NodesPreparer):
    def __init__(self, database, start_block=1) -> None:
        self.sessions = []
        self.database = database
        self.start_block = start_block

    def prepare(self, builder: networks.NetworksBuilder):
        for cnt, node in enumerate(builder.prepare_nodes):
            DB_URL = os.getenv("DB_URL")
            self.sessions.append( self.database(f"{DB_URL}-{cnt}") )

            node.config.plugin.append('sql_serializer')
            node.config.psql_url = str(self.db_url(cnt))
            node.config.psql_first_block = self.start_block
            apply_block_log_type_to_monolithic_workaround(node)

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


def prepare_network_with_1_session(database, architecture: networks.NetworksArchitecture, block_log_directory_name: Path = None, time_offsets: Iterable[int] = None) -> Tuple[networks.NetworksBuilder, Any]:
    preparer = SQLNodesPreparer(database)
    return run_whole_network(architecture, block_log_directory_name, time_offsets, preparer), preparer.sessions[0]

def prepare_network_with_1_session_from_115(database, architecture: networks.NetworksArchitecture, block_log_directory_name: Path = None, time_offsets: Iterable[int] = None) -> Tuple[networks.NetworksBuilder, Any]:
    preparer = SQLNodesPreparer(database, 115)
    return run_whole_network(architecture, block_log_directory_name, time_offsets, preparer), preparer.sessions[0]


def prepare_network_with_2_sessions(database, architecture: networks.NetworksArchitecture, block_log_directory_name: Path = None, time_offsets: Iterable[int] = None) -> Tuple[networks.NetworksBuilder, Any]:
    preparer = SQLNodesPreparer(database)
    return run_whole_network(architecture, block_log_directory_name, time_offsets, preparer), preparer.sessions


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
def prepared_networks_and_database_12_8(database) -> Tuple[networks.NetworksBuilder, Any]:
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
    architecture = networks.NetworksArchitecture()
    architecture.load(config)
    yield prepare_network_with_1_session(database, architecture, create_block_log_directory_name('block_log_12_8'), None)

@pytest.fixture()
def prepared_networks_and_database_12_8_from_115(database) -> Tuple[networks.NetworksBuilder, Any]:
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
    architecture = networks.NetworksArchitecture()
    architecture.load(config)
    yield prepare_network_with_1_session_from_115(database, architecture, create_block_log_directory_name('block_log_12_8'), None)

@pytest.fixture()
def prepared_networks_and_database_12_8_with_2_sessions(database) -> Tuple[networks.NetworksBuilder, Any]:
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
    architecture = networks.NetworksArchitecture()
    architecture.load(config)
    yield prepare_network_with_2_sessions(database, architecture, create_block_log_directory_name('block_log_12_8'), None)


@pytest.fixture()
def prepared_networks_and_database_12_8_without_block_log(database) -> Tuple[networks.NetworksBuilder, Any]:
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
    architecture = networks.NetworksArchitecture()
    architecture.load(config)
    yield prepare_network_with_1_session(database, architecture, None, None)


@pytest.fixture()
def prepared_networks_and_database_17_3(database) -> Tuple[networks.NetworksBuilder, Any]:
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
    architecture = networks.NetworksArchitecture()
    architecture.load(config)
    yield prepare_network_with_1_session(database, architecture, create_block_log_directory_name('block_log_17_3'), None)


@pytest.fixture()
def prepared_networks_and_database_4_4_4_4_4(database) -> Tuple[networks.NetworksBuilder, Any]:
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
    architecture = networks.NetworksArchitecture()
    architecture.load(config)
    time_offsets = prepare_time_offsets(architecture.nodes_number)

    yield prepare_network_with_1_session(database, architecture, create_block_log_directory_name('block_log_4_4_4_4_4'), time_offsets)


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
        architecture = networks.NetworksArchitecture()
        architecture.load(config)

        builder = networks.NetworksBuilder()
        builder.build(architecture, True)

        preparer = SQLNodesPreparer(database)
        preparer.prepare(builder)

        return preparer.node(builder, 0), preparer.sessions[0], preparer.db_url(0)

    yield make_network

@pytest.fixture()
def prepared_networks_and_database_12_8_from_60(database) -> Tuple[networks.NetworksBuilder, Any]:
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
    architecture = networks.NetworksArchitecture()
    architecture.load(config)
    yield prepare_network_with_1_session(database, architecture, create_block_log_directory_name('block_log_12_8'), None)

