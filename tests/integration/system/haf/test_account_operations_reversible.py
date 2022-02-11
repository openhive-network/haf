from pathlib import Path

from test_tools import logger, Wallet
from local_tools import run_networks, prepare_create_account_trxs, make_fork, get_account_history, back_from_fork, wait_for_irreversible_progress
from tables import AccountsReversible, AccountOperations, AccountOperationsReversible


START_TEST_BLOCK = 111


def test_account_operations_reversible(world_with_witnesses_and_database):
    logger.info(f'Start test_account_operations_reversible')

    # GIVEN
    world, session = world_with_witnesses_and_database
    run_networks(world)

    node_under_test = world.network('Beta').node('NodeUnderTest')
    wallet = Wallet(attach_to=node_under_test)
    trxs_fork = prepare_create_account_trxs(wallet, 'fork-account')

    # WHEN
    make_fork(
        world,
        at_block = START_TEST_BLOCK,
        fork_chain_trxs = trxs_fork,
    )

    # THEN
    types = get_account_history(session, 'fork-account', include_reversible=True)
    assert 'account_create_operation' in types
    assert 'account_created_operation' in types
    assert 'transfer_operation' in types

    id = session.query(AccountsReversible).filter(AccountsReversible.name == 'fork-account').one().id
    acc_ops = session.query(AccountOperationsReversible).filter(AccountOperationsReversible.account_id == id).all()
    assert len(acc_ops) == 3

    after_fork_block = back_from_fork(world)
    wait_for_irreversible_progress(node_under_test, after_fork_block)

    types_after_rewind = get_account_history(session, 'fork-account')
    assert types_after_rewind == []

    acc_ops = session.query(AccountOperations).filter(AccountOperations.account_id == id).all()
    assert acc_ops == []
