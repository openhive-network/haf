from pathlib import Path

from test_tools import logger, Wallet
from local_tools import create_node_with_database, run_networks, prepare_create_account_trxs, make_fork, back_from_fork, wait_for_irreversible_progress
from tables import Blocks, Operations, Transactions


START_TEST_BLOCK = 111


def test_compare_forked_node_database(world_with_witnesses_and_database, database):
    logger.info(f'Start test_compare_forked_node_database')

    # GIVEN
    world, session = world_with_witnesses_and_database
    session_ref = database('postgresql:///haf_block_log_ref')
    reference_node = create_node_with_database(world.network('Alpha'), session_ref.get_bind().url)
    run_networks(world)

    node_under_test = world.network('Beta').node('NodeUnderTest')
    wallet = Wallet(attach_to=node_under_test)
    trxs_main = prepare_create_account_trxs(wallet, 'main-chain-acnt')
    trxs_fork = prepare_create_account_trxs(wallet, 'fork-chain-acnt')
    trxs_third = prepare_create_account_trxs(wallet, 'alice')

    # WHEN
    after_fork_block = make_fork(
        world,
        at_block = START_TEST_BLOCK,
        main_chain_trxs = trxs_main + trxs_third,
        fork_chain_trxs = trxs_fork + trxs_third,
    )

    # THEN
    after_fork_block = back_from_fork(world)
    wait_for_irreversible_progress(node_under_test, after_fork_block)

    blks = session.query(Blocks).filter(Blocks.num < after_fork_block).order_by(Blocks.num).all()
    blks_ref = session_ref.query(Blocks).filter(Blocks.num < after_fork_block).order_by(Blocks.num).all()

    for block, block_ref in zip(blks, blks_ref):
        assert block.hash == block_ref.hash

    trxs = session.query(Transactions).filter(Transactions.block_num < after_fork_block).order_by(Transactions.trx_hash).all()
    trxs_ref = session_ref.query(Transactions).filter(Transactions.block_num < after_fork_block).order_by(Transactions.trx_hash).all()

    for trx, trx_ref in zip(trxs, trxs_ref):
        assert trx.trx_hash == trx_ref.trx_hash

    ops = session.query(Operations).filter(Operations.block_num < after_fork_block).order_by(Operations.id).all()
    ops_ref = session_ref.query(Operations).filter(Operations.block_num < after_fork_block).order_by(Operations.id).all()

    for op, op_ref in zip(ops, ops_ref):
        assert op.body == op_ref.body
