from pathlib import Path

from test_tools import logger, Asset, Wallet
from local_tools import make_fork, back_from_fork, wait_for_irreversible_progress, run_networks


START_TEST_BLOCK = 108


def test_undo_transactions(world_with_witnesses_and_database):
    logger.info(f'Start test_undo_transactions')

    # GIVEN
    world, session, Base = world_with_witnesses_and_database
    node_under_test = world.network('Beta').node('NodeUnderTest')
    transactions = Base.classes.transactions
    transactions_reversible = Base.classes.transactions_reversible

    # WHEN
    run_networks(world, Path().resolve())
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    wallet = Wallet(attach_to=node_under_test)
    transaction = wallet.api.transfer_to_vesting('initminer', 'null', Asset.Test(1234), broadcast=False)

    make_fork(
        world,
        fork_chain_trxs = [transaction],
    )

    # THEN
    trx = session.query(transactions_reversible).filter(transactions_reversible.block_num > START_TEST_BLOCK).one()
    logger.info(f'Found transaction with hash {trx.trx_hash} on block {trx.block_num}, this will be reverted')

    after_fork_block = back_from_fork(world)
    wait_for_irreversible_progress(node_under_test, after_fork_block)
    trxs = session.query(transactions).filter(transactions.block_num > START_TEST_BLOCK).all()
    assert trxs == []
    logger.info(f'Found no transactions on main chain')
