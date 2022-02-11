from pathlib import Path

from test_tools import logger, Wallet
from local_tools import *


START_TEST_BLOCK = 111


def test_undo_account_operations(world_with_witnesses_and_database):
    logger.info(f'Start test_undo_account_operations')

    # GIVEN
    world, session = world_with_witnesses_and_database
    run_networks(world, Path().resolve())

    node_under_test = world.network('Beta').node('NodeUnderTest')
    wallet = Wallet(attach_to=node_under_test)
    trxs_main = prepare_create_account_trxs(wallet, 'dummy-account')
    trxs_fork = prepare_create_account_trxs(wallet, 'fork-account')

    # WHEN
    make_fork(
        world,
        at_block = START_TEST_BLOCK,
        main_chain_trxs = trxs_main,
        fork_chain_trxs = trxs_fork,
    )

    # THEN
    types = get_account_history(session, 'fork-account', include_reversible=True)
    assert 'account_create_operation' in types
    assert 'account_created_operation' in types
    assert 'transfer_operation' in types

    after_fork_block = back_from_fork(world)
    wait_for_irreversible_progress(node_under_test, after_fork_block)

    fork_account_types = get_account_history(session, 'fork-account')
    assert fork_account_types == []

    main_account_types = get_account_history(session, 'dummy-account')
    assert 'account_create_operation' in main_account_types
    assert 'account_created_operation' in main_account_types
    assert 'transfer_operation' in main_account_types
