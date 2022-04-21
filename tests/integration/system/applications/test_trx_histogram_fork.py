from sqlalchemy.orm.session import sessionmaker

from test_tools import logger, Wallet, Asset
from local_tools import run_networks, make_fork, get_head_block, wait_for_irreversible_progress, run_networks, create_app, update_app_continuously, wait_for_application_context


START_TEST_BLOCK = 108
APPLICATION_CONTEXT = "trx_histogram"


def test_trx_histogram_fork(world_with_witnesses_and_database):
    logger.info(f'Start test_trx_histogram_fork')

    # GIVEN
    world, session, Base = world_with_witnesses_and_database
    second_session = sessionmaker()(bind = session.get_bind())
    alpha_node = world.network('Alpha').node('WitnessNode0')
    node_under_test = world.network('Beta').node('NodeUnderTest')
    transactions_reversible = Base.classes.transactions_reversible

    # WHEN
    run_networks(world)
    alpha_wallet = Wallet(attach_to=alpha_node)
    beta_wallet = Wallet(attach_to=node_under_test)
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)

    # system under test
    create_app(second_session, APPLICATION_CONTEXT)

    blocks_range = session.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone()
    (first_block, last_block) = blocks_range

    session.execute( "SELECT hive.app_context_detach( '{}' )".format( APPLICATION_CONTEXT ) )
    session.execute( "SELECT public.update_histogram( {}, {} )".format( first_block, last_block ) )
    session.execute( "SELECT hive.app_context_attach( '{}', {} )".format( APPLICATION_CONTEXT, last_block ) )
    session.commit()
    
    # THEN
    histogram = session.execute( "SELECT * FROM public.trx_histogram").fetchone()
    logger.info( "histogram: {}\n".format( histogram ) )
    assert histogram['trx'] == 3 # number of transactions in prepared block_log

    with update_app_continuously(second_session, APPLICATION_CONTEXT):
        trx1 = alpha_wallet.api.transfer('initminer', 'initminer', Asset.Test(1000), 'dummy transfer operation in alpha net', broadcast=False)
        trx2 = beta_wallet.api.transfer('initminer', 'initminer', Asset.Test(1000), 'dummy transfer operation in beta net', broadcast=False)
        trx3 = beta_wallet.api.transfer('initminer', 'initminer', Asset.Test(1000), 'another dummy transfer operation in beta net', broadcast=False)
        after_fork_block = make_fork(
            world,
            main_chain_trxs = [trx1],
            fork_chain_trxs = [trx2, trx3],
        )
        wait_for_application_context(session, get_head_block(node_under_test))

        histogram = session.execute( "SELECT * FROM public.trx_histogram").fetchone()
        logger.info( "histogram: {}\n".format( histogram ) )
        assert histogram['trx'] == 4
        trx_sent = session.query(transactions_reversible).all()
        assert len(trx_sent) == 3

        wait_for_irreversible_progress(node_under_test, after_fork_block)
        wait_for_application_context(session, get_head_block(node_under_test))

        histogram = session.execute( "SELECT * FROM public.trx_histogram").fetchone()
        logger.info( "histogram: {}\n".format( histogram ) )
        assert histogram['trx'] == 4
        trx_sent = session.query(transactions_reversible).all()
        assert len(trx_sent) == 0
