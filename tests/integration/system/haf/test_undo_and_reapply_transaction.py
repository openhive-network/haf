from pathlib import Path

from test_tools import logger, Wallet
from local_tools import *
from tables import Transactions, TransactionsReversible, TransactionsMultisig


START_TEST_BLOCK = 111


def test_undo_and_reapply_transaction(world_with_witnesses_and_database):
    logger.info(f'Start test_undo_and_reapply_transaction')

    # GIVEN
    world, session = world_with_witnesses_and_database
    run_networks(world, Path().resolve())

    node_under_test = world.network('Beta').node('NodeUnderTest')
    transaction = prepare_transaction1_multisig(Wallet(attach_to=node_under_test))

    # WHEN
    make_fork(
        world,
        at_block = START_TEST_BLOCK,
        main_chain_trxs = [transaction],
        fork_chain_trxs = [transaction],
    )

    after_fork_block = back_from_fork(world)

    # THEN
    trxs = session.query(Transactions).filter(Transactions.block_num > START_TEST_BLOCK).all()
    assert len(trxs) == 0
    trxs_rev = session.query(TransactionsReversible).filter(TransactionsReversible.block_num > START_TEST_BLOCK).all()
    assert len(trxs_rev) == 2

    wait_for_irreversible_progress(node_under_test, after_fork_block)

    trx = session.query(Transactions).filter(Transactions.block_num > START_TEST_BLOCK).one()
    session.query(TransactionsMultisig).filter(TransactionsMultisig.trx_hash == trx.trx_hash).one()
    trxs_rev = session.query(TransactionsReversible).filter(TransactionsReversible.block_num > START_TEST_BLOCK).all()
    assert trxs_rev == []