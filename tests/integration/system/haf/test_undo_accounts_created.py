from pathlib import Path

from test_tools import logger, Wallet
from local_tools import run_networks, make_fork, back_from_fork, wait_for_irreversible_progress
from tables import Accounts, AccountsReversible


START_TEST_BLOCK = 111


def test_undo_accounts_created(world_with_witnesses_and_database):
    logger.info(f'Start test_undo_accounts_created')

    # GIVEN
    world, session = world_with_witnesses_and_database
    run_networks(world)

    node_under_test = world.network('Beta').node('NodeUnderTest')
    wallet = Wallet(attach_to=node_under_test)
    transaction1 = wallet.api.create_account('initminer', 'dummy-account', '', broadcast=False)
    transaction2 = wallet.api.create_account('initminer', 'dummy2-account', '', broadcast=False)
    transaction3 = wallet.api.create_account('initminer', 'fork-account', '', broadcast=False)

    # WHEN
    make_fork(
        world,
        at_block = START_TEST_BLOCK,
        main_chain_trxs = [transaction1, transaction2],
        fork_chain_trxs = [transaction1, transaction3],
    )

    # THEN
    session.query(AccountsReversible).filter(AccountsReversible.name == 'fork-account').one()
    after_fork_block = back_from_fork(world)
    wait_for_irreversible_progress(node_under_test, after_fork_block)

    session.query(Accounts).filter(Accounts.name == 'dummy-account').one()
    session.query(Accounts).filter(Accounts.name == 'dummy2-account').one()
    acc = session.query(Accounts).filter(Accounts.name == 'fork-account').all()
    assert acc == []
