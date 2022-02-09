from pathlib import Path

from test_tools import logger, Wallet, Asset
from local_tools import run_networks, make_fork, back_from_fork, wait_for_application_context
from threading import Thread

from haf_utilities import args_container
from haf_base import application
from haf_memo_scanner import sql_memo_scanner


START_TEST_BLOCK = 108


def test_memo_scanner_same_trx_on_fork(world_with_witnesses_and_database):
    logger.info(f'Start test_memo_scanner_same_trx_on_fork')

    # GIVEN
    world, session = world_with_witnesses_and_database
    alpha_witness_node = world.network('Alpha').node('WitnessNode0')
    node_under_test = world.network('Beta').node('NodeUnderTest')

    run_networks(world, Path().resolve())
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    alpha_wallet = Wallet(attach_to=alpha_witness_node)
    beta_wallet = Wallet(attach_to=node_under_test)

    # system under test
    def thread_func():
        _schema_name = "memo_scanner"
        _sql_memo_scanner = sql_memo_scanner("dummy", _schema_name)
        application(args_container(session.get_bind().url, 1000, 1), _schema_name + "_app", _sql_memo_scanner)
        _sql_memo_scanner.total_run()
    Thread(daemon=True, target=thread_func).start()

    prepared_trx = alpha_wallet.api.transfer('initminer', 'initminer', Asset.Test(1000), f'dummy transfer operation', broadcast=False)
    prepared_trx2 = beta_wallet.api.transfer('initminer', 'initminer', Asset.Test(1000), f'dummy transfer operation 2', broadcast=False)

    # WHEN
    make_fork(
        world,
        at_block = START_TEST_BLOCK,
        main_chain_trxs = [prepared_trx],
        fork_chain_trxs = [prepared_trx, prepared_trx2],
    )
    wait_for_application_context(session)
  
    memos = session.execute( "SELECT * FROM memo_scanner.memos").all()
    logger.info( "memos: {}\n".format( memos ) )
    assert len(memos) == 2 # assert there are trx from fork

    back_from_fork(world)
    wait_for_application_context(session)

    memos = session.execute( "SELECT * FROM memo_scanner.memos").all()
    logger.info( "memos: {}\n".format( memos ) )
    assert len(memos) == 1 # assert there is only trx sent on main chain
