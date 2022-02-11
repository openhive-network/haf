from pathlib import Path

from test_tools import logger, Asset, Wallet
from local_tools import make_fork, back_from_fork, wait_for_irreversible_progress, run_networks
from tables import Transactions, TransactionsReversible


START_TEST_BLOCK = 111


def test_undo_transactions(world_with_witnesses_and_database):
    logger.info(f'Start test_undo_transactions')

    # GIVEN
    world, session = world_with_witnesses_and_database
    run_networks(world, Path().resolve())

    node_under_test = world.network('Beta').node('NodeUnderTest')
    wallet = Wallet(attach_to=node_under_test)
    transaction = wallet.api.transfer_to_vesting('initminer', 'null', Asset.Test(1234), broadcast=False)

    # WHEN
    make_fork(
        world,
        at_block = START_TEST_BLOCK,
        fork_chain_trxs = [transaction],
    )

    # THEN
    trx = session.query(TransactionsReversible).filter(TransactionsReversible.block_num > START_TEST_BLOCK).one()
    logger.info(f'Found transaction with hash {trx.trx_hash} on block {trx.block_num}, this will be reverted')

    after_fork_block = back_from_fork(world)
    wait_for_irreversible_progress(node_under_test, after_fork_block)
    trxs = session.query(Transactions).filter(Transactions.block_num > START_TEST_BLOCK).all()
    assert trxs == []
    logger.info(f'Found no transactions on main chain')
