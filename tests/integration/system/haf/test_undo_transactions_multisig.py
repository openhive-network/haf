from pathlib import Path

from test_tools import logger, Wallet
from local_tools import run_networks, prepare_transaction1_multisig, prepare_transaction2_multisig, make_fork, back_from_fork, wait_for_irreversible_progress
from tables import Transactions, TransactionsReversible, TransactionsMultisig, TransactionsMultisigReversible


START_TEST_BLOCK = 111


def test_undo_transactions_multisig(world_with_witnesses_and_database):
    logger.info(f'Start test_undo_transactions_multisig')

    # GIVEN
    world, session = world_with_witnesses_and_database
    run_networks(world)

    node_under_test = world.network('Beta').node('NodeUnderTest')
    wallet = Wallet(attach_to=node_under_test)
    trx1 = prepare_transaction1_multisig(wallet)
    trx2 = prepare_transaction2_multisig(wallet)

    # WHEN
    make_fork(
        world,
        at_block = START_TEST_BLOCK,
        main_chain_trxs = [trx1],
        fork_chain_trxs = [trx1, trx2],
    )

    # THEN
    trxs_fork = session.query(TransactionsReversible).filter(TransactionsReversible.block_num > START_TEST_BLOCK).all()
    assert len(trxs_fork) == 2
    logger.info(f'Found transaction with hash {trxs_fork[0].trx_hash} on block {trxs_fork[0].block_num}, this will be reverted')
    session.query(TransactionsMultisigReversible).filter(TransactionsMultisigReversible.trx_hash == trxs_fork[0].trx_hash).one()
    logger.info(f'Found transaction with hash {trxs_fork[1].trx_hash} on block {trxs_fork[1].block_num}, this will be reverted')
    session.query(TransactionsMultisigReversible).filter(TransactionsMultisigReversible.trx_hash == trxs_fork[1].trx_hash).one()

    after_fork_block = back_from_fork(world)
    wait_for_irreversible_progress(node_under_test, after_fork_block)
    trx_main = session.query(Transactions).filter(Transactions.block_num > START_TEST_BLOCK).one()
    trx_hash_main = trx_main.trx_hash
    logger.info(f'Found transaction with hash {trx_hash_main} on block {trx_main.block_num}')

    session.query(TransactionsMultisig).filter(TransactionsMultisig.trx_hash == trx_hash_main).one()
