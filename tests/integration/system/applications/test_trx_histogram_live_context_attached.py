from pathlib import Path
from sqlalchemy.orm.session import sessionmaker

from test_tools import logger, Wallet, Asset
from local_tools import run_networks, run_networks, create_app, update_app_continuously


START_TEST_BLOCK = 108
APPLICATION_CONTEXT = "trx_histogram"


def test_trx_histogram_live_context_attached(world_with_witnesses_and_database):
    logger.info(f'Start test_trx_histogram_live_context_attached')

    # GIVEN
    world, session = world_with_witnesses_and_database
    second_session = sessionmaker()(bind = session.get_bind())
    node_under_test = world.network('Beta').node('NodeUnderTest')

    # WHEN
    run_networks(world, Path().resolve())
    wallet = Wallet(attach_to=node_under_test)
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)

    # system under test
    create_app(second_session, APPLICATION_CONTEXT)
    with update_app_continuously(second_session, APPLICATION_CONTEXT):
        # THEN
        node_under_test.wait_number_of_blocks(1)
        histogram = session.execute( "SELECT * FROM public.trx_histogram").fetchone()
        logger.info( "histogram: {}\n".format( histogram ) )
        assert histogram['trx'] == 4 # number of transactions in prepared block_log

        # create dummy transfer operation
        trx = wallet.api.transfer('initminer', 'initminer', Asset.Test(1000), 'dummy transfer operation')
        node_under_test.wait_number_of_blocks(1)

        context = session.execute( "SELECT * FROM hive.contexts").fetchone()
        logger.info( "context: {}\n".format( context ) )
        assert context['current_block_num'] >= trx['block_num']

        histogram = session.execute( "SELECT * FROM public.trx_histogram").fetchone()
        logger.info( "histogram: {}\n".format( histogram ) )
        assert histogram['trx'] == 5
