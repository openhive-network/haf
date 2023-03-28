from pathlib import Path
from typing import Any, Tuple, Iterable
from uuid import uuid4
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
from shared_tools.complex_networks import sql_preparer, run_whole_network, prepare_time_offsets, create_block_log_directory_name


def prepare_database( database, name: str = "haf_block_log") -> Any:
    return database(f"postgresql:///{name}")


def prepare_network_with_1_session(database, architecture: networks.NetworksArchitecture, block_log_directory_name: Path = None, time_offsets: Iterable[int] = None, preparer: sql_preparer = None) -> Tuple[networks.NetworksBuilder, Any]:
    preparer.session = prepare_database(database)
    return run_whole_network(architecture, block_log_directory_name, time_offsets, [preparer]), preparer.session


def prepare_network_with_2_sessions(database, architecture: networks.NetworksArchitecture, block_log_directory_name: Path = None, time_offsets: Iterable[int] = None, preparers: Iterable[sql_preparer] = None) -> Tuple[networks.NetworksBuilder, Any]:
    preparers[0].session = prepare_database(database)
    preparers[1].session = prepare_database(database, "haf_block_log_ref")
    return run_whole_network(architecture, block_log_directory_name, time_offsets, preparers), [preparers[0].session, preparers[1].session]

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
    yield prepare_network_with_1_session(database, architecture, create_block_log_directory_name('block_log_12_8'), None, sql_preparer(1, 'ApiNode0'))

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
    yield prepare_network_with_2_sessions(database, architecture, create_block_log_directory_name('block_log_12_8'), None, sql_preparers)

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
    yield prepare_network_with_1_session(database, architecture, None, None, sql_preparer(1, 'ApiNode0'))

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
    yield prepare_network_with_1_session(database, architecture, create_block_log_directory_name('block_log_17_3'), None, sql_preparer(1, 'ApiNode1'))

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

    yield prepare_network_with_1_session(database, architecture, create_block_log_directory_name('block_log_4_4_4_4_4'), time_offsets, sql_preparer(1, 'ApiNode0'))


@pytest.fixture()
def prepared_networks_and_database_1() -> Tuple[tt.ApiNode, Any, Any]:

    def make_network(database) -> Tuple[tt.ApiNode, Any, Any]:
        config = {
            "networks": [
                            {
                                "ApiNode"   : True,
                            }
                        ]
        }
        architecture = networks.NetworksArchitecture()
        architecture.load(config)

        builder = networks.NetworksBuilder()
        builder.build(architecture, True)

        network_under_test      = 0
        node_under_test_name    = "ApiNode0"

        preparer = sql_preparer(network_under_test, node_under_test_name, prepare_database(database))
        preparer.prepare(builder)

        return preparer.node(builder), preparer.session, preparer.db_name()

    yield make_network
