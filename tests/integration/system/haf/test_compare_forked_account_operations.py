from pathlib import Path

from test_tools import logger, Wallet
from local_tools import create_node_with_database, run_networks, prepare_create_account_trxs, make_fork, back_from_fork, wait_for_irreversible_progress
from tables import Accounts, AccountOperations, Operations


START_TEST_BLOCK = 111


def test_compare_forked_account_operations(world_with_witnesses_and_database, database):
    logger.info(f'Start test_compare_forked_account_operations')

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
    make_fork(
        world,
        at_block = START_TEST_BLOCK,
        main_chain_trxs = trxs_main + trxs_third,
        fork_chain_trxs = trxs_fork + trxs_third,
    )

    # THEN
    after_fork_block = back_from_fork(world)
    wait_for_irreversible_progress(node_under_test, after_fork_block)

    acc_ops = session.query(Accounts.name, Operations.body, Operations.timestamp, AccountOperations.account_op_seq_no).\
        join(Accounts, Accounts.id == AccountOperations.account_id).\
        join(Operations, Operations.id == AccountOperations.operation_id).\
        order_by(Accounts.name, AccountOperations.account_op_seq_no).\
        all()

    acc_ops_ref = session_ref.query(Accounts.name, Operations.body, Operations.timestamp, AccountOperations.account_op_seq_no).\
        join(Accounts, Accounts.id == AccountOperations.account_id).\
        join(Operations, Operations.id == AccountOperations.operation_id).\
        order_by(Accounts.name, AccountOperations.account_op_seq_no).\
        all()

    for acc_op, acc_op_ref in zip(acc_ops, acc_ops_ref):
        assert acc_op.name == acc_op_ref.name
        assert acc_op.account_op_seq_no == acc_op_ref.account_op_seq_no
        assert acc_op.body == acc_op_ref.body
        assert acc_op.timestamp == acc_op_ref.timestamp
