from pathlib import Path
from typing import Any, Iterable, Tuple
from uuid import uuid4
from functools import partial
import random
import sys

import pytest
import sqlalchemy
from sqlalchemy_utils import database_exists, create_database, drop_database
from sqlalchemy.ext.automap import automap_base
from sqlalchemy.orm import sessionmaker, close_all_sessions
from sqlalchemy.pool import NullPool

from test_tools.__private.scope.scope_fixtures import *  # pylint: disable=wildcard-import, unused-wildcard-import
import test_tools as tt

import shared_tools.networks_architecture as networks
from shared_tools.complex_networks import prepare_sub_networks

def prepare_time_offsets(limit: int):
    time_offsets = []

    cnt = 0
    for i in range(limit):
        time_offsets.append(cnt % 3 + 1)
        cnt += 1

    result = ",".join(str(time_offset) for time_offset in time_offsets)
    tt.logger.info( f"Generated: {result}" )

    return time_offsets

def create_block_log_directory_name(name : str):
    return Path(__file__).parent.absolute() / "system" / "haf" / name

@pytest.fixture()
def database():
    """
    Returns factory function that creates database with parametrized name and extension hive_fork_manager installed
    """

    def make_database(url):
        url = url + '_' + uuid4().hex
        tt.logger.info(f'Preparing database {url}')
        if database_exists(url):
            drop_database(url)
        create_database(url)

        engine = sqlalchemy.create_engine(url, echo=False, poolclass=NullPool)
        with engine.connect() as connection:
            connection.execute('CREATE EXTENSION hive_fork_manager CASCADE;')

        with engine.connect() as connection:
            connection.execute('SET ROLE hived_group')

        Session = sessionmaker(bind=engine)
        session = Session()

        return session

    yield make_database

    close_all_sessions()

class sql_preparer:
    def __init__(self, network_under_test: int, node_under_test_name: str) -> None:
        self.network_under_test     = network_under_test
        self.node_under_test_name   = node_under_test_name
        self.session                = None

    def prepare(self, builder: networks.NetworksBuilder):
        node_under_test = builder.networks[self.network_under_test].node(self.node_under_test_name)
        node_under_test.config.plugin.append('sql_serializer')
        node_under_test.config.psql_url = str(self.session.get_bind().url)

def before_run_network(builder: networks.NetworksBuilder, preparers: Iterable[sql_preparer]):
    for preparer in preparers:
        preparer.prepare(builder)

    for node in builder.nodes:
        node.config.log_logger = '{"name":"default","level":"debug","appender":"stderr,p2p"} '\
                                 '{"name":"user","level":"debug","appender":"stderr,p2p"} '\
                                 '{"name":"chainlock","level":"debug","appender":"p2p"} '\
                                 '{"name":"sync","level":"debug","appender":"p2p"} '\
                                 '{"name":"p2p","level":"debug","appender":"p2p"}'

def prepare_basic_networks_internal(database, architecture: networks.NetworksArchitecture, block_log_directory_name: Path = None, time_offsets: Iterable[int] = None, preparers: Iterable[sql_preparer] = None) -> Tuple[networks.NetworksBuilder, Any]:
    builder = prepare_sub_networks(architecture, block_log_directory_name, time_offsets, partial( before_run_network, preparers=preparers))

    if builder == None:
        tt.logger.info(f"Generating 'block_log' enabled. Exiting...")
        sys.exit(1)

    return builder

def prepare_basic_networks(database, architecture: networks.NetworksArchitecture, block_log_directory_name: Path = None, time_offsets: Iterable[int] = None, preparer: sql_preparer = None) -> Tuple[networks.NetworksBuilder, Any]:
    preparer.session = database('postgresql:///haf_block_log')
    return prepare_basic_networks_internal(database, architecture, block_log_directory_name, time_offsets, [preparer]), preparer.session

def prepare_basic_networks_with_2_sessions(database, architecture: networks.NetworksArchitecture, block_log_directory_name: Path = None, time_offsets: Iterable[int] = None, preparers: Iterable[sql_preparer] = None) -> Tuple[networks.NetworksBuilder, Any]:
    preparers[0].session = database('postgresql:///haf_block_log')
    preparers[1].session = database('postgresql:///haf_block_log_ref')
    return prepare_basic_networks_internal(database, architecture, block_log_directory_name, time_offsets, preparers), [preparers[0].session, preparers[1].session]

@pytest.fixture()
def prepared_networks_and_database_12_8(database) -> Tuple[networks.NetworksBuilder, Any]:
    config = {
        "networks": [
                        {
                            "InitNode"     : True,
                            "WitnessNodes" :[12]
                        },
                        {
                            "ApiNode"      : True,
                            "WitnessNodes" :[8]
                        }
                    ]
    }
    architecture = networks.NetworksArchitecture()
    architecture.load(config)
    yield prepare_basic_networks(database, architecture, create_block_log_directory_name('block_log_12_8'), None, sql_preparer(1, 'ApiNode0'))

@pytest.fixture()
def prepared_networks_and_database_12_8_with_2_sessions(database) -> Tuple[networks.NetworksBuilder, Any]:
    config = {
        "networks": [
                        {
                            "InitNode"     : True,
                            "ApiNode"      : True,
                            "WitnessNodes" :[12]
                        },
                        {
                            "ApiNode"      : True,
                            "WitnessNodes" :[8]
                        }
                    ]
    }
    architecture = networks.NetworksArchitecture()
    architecture.load(config)
    sql_preparers = [sql_preparer(0, 'ApiNode0'), sql_preparer(1, 'ApiNode1')]
    yield prepare_basic_networks_with_2_sessions(database, architecture, create_block_log_directory_name('block_log_12_8'), None, sql_preparers)

@pytest.fixture()
def prepared_networks_and_database_12_8_without_block_log(database) -> Tuple[networks.NetworksBuilder, Any]:
    config = {
        "networks": [
                        {
                            "InitNode"     : True,
                            "WitnessNodes" :[12]
                        },
                        {
                            "ApiNode"      : True,
                            "WitnessNodes" :[8]
                        }
                    ]
    }
    architecture = networks.NetworksArchitecture()
    architecture.load(config)
    yield prepare_basic_networks(database, architecture, None, None, sql_preparer(1, 'ApiNode0'))

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
                            "ApiNode"      : True,
                            "WitnessNodes" :[3]
                        }
                    ]
    }
    architecture = networks.NetworksArchitecture()
    architecture.load(config)
    yield prepare_basic_networks(database, architecture, create_block_log_directory_name('block_log_17_3'), None, sql_preparer(1, 'ApiNode1'))

@pytest.fixture()
def prepared_networks_and_database_4_4_4_4_4(database) -> Tuple[networks.NetworksBuilder, Any]:
    config = {
        "networks": [
                        {
                            "InitNode"     : True,
                            "WitnessNodes" :[4]
                        },
                        {
                            "ApiNode"      : True,
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

    yield prepare_basic_networks(database, architecture, create_block_log_directory_name('block_log_4_4_4_4_4'), time_offsets, sql_preparer(1, 'ApiNode0'))
