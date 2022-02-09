from pathlib import Path
from sqlalchemy.orm.session import sessionmaker

from test_tools import logger, Wallet, Asset
from local_tools import run_networks, run_networks, create_app, update_app_continuously


START_TEST_BLOCK = 108
APPLICATION_CONTEXT = "trx_histogram"


def test_trx_histogram_live_context_detached(world_with_witnesses_and_database):
    logger.info(f'Start test_trx_histogram_live_context_detached')

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

    # THEN
    context = session.execute( "SELECT * FROM hive.contexts").fetchone()
    logger.info( "context: {}\n".format( context ) )
    assert context['current_block_num'] == 0 # before any update should be zero

    blocks_range = session.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone()
    (first_block, last_block) = blocks_range
    session.execute( "SELECT hive.app_context_detach( '{}' )".format( APPLICATION_CONTEXT ) )
    session.execute( "SELECT public.update_histogram( {}, {} )".format( first_block, last_block ) )
    session.execute( "SELECT hive.app_context_attach( '{}', {} )".format( APPLICATION_CONTEXT, last_block ) )
    session.commit()

    histogram = session.execute( "SELECT * FROM public.trx_histogram").fetchone()
    logger.info( "histogram: {}\n".format( histogram ) )
    assert histogram['trx'] == 4 # number of transactions in prepared block_log

    with update_app_continuously(second_session, APPLICATION_CONTEXT):

        # create dummy transfer operation
        trx = wallet.api.transfer('initminer', 'initminer', Asset.Test(1000), 'dummy transfer operation')
        node_under_test.wait_number_of_blocks(1)

        context = session.execute( "SELECT * FROM hive.contexts").fetchone()
        logger.info( "context: {}\n".format( context ) )
        assert context['current_block_num'] >= trx['block_num']

        histogram = session.execute( "SELECT * FROM public.trx_histogram").fetchone()
        logger.info( "histogram: {}\n".format( histogram ) )
        assert histogram['trx'] == 5
