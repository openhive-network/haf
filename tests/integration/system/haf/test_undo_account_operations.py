from pathlib import Path
from sqlalchemy.orm.exc import MultipleResultsFound, NoResultFound

from test_tools import logger, Asset, Wallet
from local_tools import make_fork, back_from_fork, wait_for_irreversible_progress, run_networks, get_account_history


START_TEST_BLOCK = 108


def test_undo_account_operations(world_with_witnesses_and_database):
    logger.info(f'Start test_undo_account_operations')

    # GIVEN
    world, session, Base = world_with_witnesses_and_database
    node_under_test = world.network('Beta').node('NodeUnderTest')

    # WHEN
    run_networks(world, Path().resolve())
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    wallet = Wallet(attach_to=node_under_test)
    trxs_main = prepare_trxs_main(wallet)
    trxs_fork = prepare_trxs_fork(wallet)

    make_fork(
        world,
        main_chain_trxs = trxs_main,
        fork_chain_trxs = trxs_fork,
    )

    # THEN
    types = get_account_history(session, Base, 'fork-account', reversible=True)
    assert 'account_create_operation' in types
    assert 'account_created_operation' in types
    assert 'transfer_operation' in types

    after_fork_block = back_from_fork(world)
    wait_for_irreversible_progress(node_under_test, after_fork_block)

    fork_account_types = get_account_history(session, Base, 'fork-account')
    assert fork_account_types == []

    main_account_types = get_account_history(session, Base, 'main-account')
    assert 'account_create_operation' in main_account_types
    assert 'account_created_operation' in main_account_types
    assert 'transfer_operation' in main_account_types


def prepare_trxs_main(wallet):
    transaction1 = wallet.api.create_account('initminer', 'main-account', '', broadcast=False)
    transaction2 = wallet.api.transfer('initminer', 'main-account', Asset.Test(1), 'memo', broadcast=False)

    return [transaction1, transaction2]


def prepare_trxs_fork(wallet):
    transaction1 = wallet.api.create_account('initminer', 'fork-account', '', broadcast=False)
    transaction2 = wallet.api.transfer('initminer', 'fork-account', Asset.Test(3), 'memo', broadcast=False)

    return [transaction1, transaction2]
