from pathlib import Path
from sqlalchemy.orm.exc import MultipleResultsFound, NoResultFound

from test_tools import logger, Asset, Wallet
from local_tools import make_fork, back_from_fork, wait_for_irreversible_progress, run_networks, get_account_history


START_TEST_BLOCK = 108


def test_account_operations_reversible(world_with_witnesses_and_database):
    logger.info(f'Start test_account_operations_reversible')

    # GIVEN
    world, session, Base = world_with_witnesses_and_database
    node_under_test = world.network('Beta').node('NodeUnderTest')
    accounts_reversible = Base.classes.accounts_reversible
    account_operations = Base.classes.account_operations
    account_operations_reversible = Base.classes.account_operations_reversible

    # WHEN
    run_networks(world, Path().resolve())
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    wallet = Wallet(attach_to=node_under_test)
    trxs_fork = prepare_trxs_fork(wallet)

    make_fork(
        world,
        fork_chain_trxs = trxs_fork,
    )

    # THEN
    types = get_account_history(session, Base, 'fork-account', reversible=True)
    assert 'account_create_operation' in types
    assert 'account_created_operation' in types
    assert 'transfer_operation' in types

    id = session.query(accounts_reversible).filter(accounts_reversible.name == 'fork-account').one().id
    acc_ops = session.query(account_operations_reversible).filter(account_operations_reversible.account_id == id).all()
    assert len(acc_ops) == 3

    after_fork_block = back_from_fork(world)
    wait_for_irreversible_progress(node_under_test, after_fork_block)

    fork_account_types = get_account_history(session, Base, 'fork-account')
    assert fork_account_types == []

    acc_ops = session.query(account_operations).filter(account_operations.account_id == id).all()
    assert acc_ops == []


def prepare_trxs_fork(wallet):
    transaction1 = wallet.api.create_account('initminer', 'fork-account', '', broadcast=False)
    transaction2 = wallet.api.transfer('initminer', 'fork-account', Asset.Test(3), 'memo', broadcast=False)

    return [transaction1, transaction2]
