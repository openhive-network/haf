import pytest
import sqlalchemy
from sqlalchemy_utils import database_exists, create_database, drop_database
from sqlalchemy.ext.automap import automap_base
from sqlalchemy.orm import sessionmaker, close_all_sessions
from sqlalchemy.pool import NullPool
from uuid import uuid4

from test_tools.__private.scope.scope_fixtures import *  # pylint: disable=wildcard-import, unused-wildcard-import
import test_tools as tt

from witnesses import alpha_witness_names, beta_witness_names


def pytest_exception_interact(report):
    tt.logger.error(f'Test exception:\n{report.longreprtext}')


@pytest.fixture()
def witness_names():
    return alpha_witness_names, beta_witness_names


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

        metadata = sqlalchemy.MetaData(schema="hive")
        Base = automap_base(bind=engine, metadata=metadata)
        Base.prepare(reflect=True)

        return session, Base

    yield make_database

    close_all_sessions()


@pytest.fixture()
def prepared_networks_and_database(database, witness_names):
    alpha_witness_names, beta_witness_names = witness_names
    session, Base = database('postgresql:///haf_block_log')

    alpha_net = tt.Network()
    tt.WitnessNode(network=alpha_net, witnesses=alpha_witness_names)

    beta_net = tt.Network()
    tt.WitnessNode(network=beta_net, witnesses=beta_witness_names)
    node_under_test = tt.ApiNode(network=beta_net)
    node_under_test.config.plugin.append('sql_serializer')
    node_under_test.config.psql_url = str(session.get_bind().url)

    for node in [*alpha_net.nodes, *beta_net.nodes]:
        node.config.log_logger = '{"name":"default","level":"debug","appender":"stderr,p2p"} '\
                                 '{"name":"user","level":"debug","appender":"stderr,p2p"} '\
                                 '{"name":"chainlock","level":"debug","appender":"p2p"} '\
                                 '{"name":"sync","level":"debug","appender":"p2p"} '\
                                 '{"name":"p2p","level":"debug","appender":"p2p"}'

    networks = {
        'Alpha': alpha_net,
        'Beta': beta_net,
    }

    yield networks, session, Base
