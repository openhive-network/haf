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
from shared_tools.complex_networks import prepare_sub_networks_v2

def prepare_time_offsets(limit: int):
    time_offsets = []

    for i in range(limit):
        time_offsets.append(random.randint(0, 3))

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

class networks_details:
    def __init__(self, network_under_test: int, node_under_test_name: str) -> None:
        self.network_under_test     = network_under_test
        self.node_under_test_name   = node_under_test_name

def before_run_network(builder: networks.NetworksBuilder, session: sessionmaker, details: networks_details):
    node_under_test = builder.networks[details.network_under_test].node(details.node_under_test_name)
    node_under_test.config.plugin.append('sql_serializer')
    node_under_test.config.psql_url = str(session.get_bind().url)

    for node in builder.nodes:
        node.config.log_logger = '{"name":"default","level":"debug","appender":"stderr,p2p"} '\
                                 '{"name":"user","level":"debug","appender":"stderr,p2p"} '\
                                 '{"name":"chainlock","level":"debug","appender":"p2p"} '\
                                 '{"name":"sync","level":"debug","appender":"p2p"} '\
                                 '{"name":"p2p","level":"debug","appender":"p2p"}'

def prepare_basic_networks(database, architecture: networks.NetworksArchitecture, block_log_directory_name: Path = None, time_offsets: Iterable[int] = None, details: networks_details = None) -> Tuple[networks.NetworksBuilder, Any]:
    session = database('postgresql:///haf_block_log')

    builder = prepare_sub_networks_v2(architecture, block_log_directory_name, time_offsets, partial( before_run_network, session=session, details=details))

    if builder == None:
        tt.logger.info(f"Generating 'block_log' enabled. Exiting...")
        sys.exit(1)


    return builder, session

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
    yield prepare_basic_networks(database, architecture, create_block_log_directory_name('block_log_12_8'), None, networks_details(1, 'ApiNode0'))

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
    yield prepare_basic_networks(database, architecture, None, None, networks_details(1, 'ApiNode0'))

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
    yield prepare_basic_networks(database, architecture, create_block_log_directory_name('block_log_17_3'), None, networks_details(1, 'ApiNode1'))

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

    yield prepare_basic_networks(database, architecture, create_block_log_directory_name('block_log_4_4_4_4_4'), time_offsets, networks_details(1, 'ApiNode0'))
