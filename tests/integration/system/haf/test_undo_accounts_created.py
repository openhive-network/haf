from pathlib import Path
from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm.exc import MultipleResultsFound

from test_tools import logger, Asset, Wallet
from local_tools import make_fork, back_from_fork, wait_for_irreversible_progress, run_networks


START_TEST_BLOCK = 108


def test_undo_accounts_created(world_with_witnesses_and_database):
    logger.info(f'Start test_undo_accounts_created')

    # GIVEN
    world, session, Base = world_with_witnesses_and_database
    node_under_test = world.network('Beta').node('NodeUnderTest')
    accounts = Base.classes.accounts
    accounts_reversible = Base.classes.accounts_reversible

    # WHEN
    run_networks(world, Path().resolve())
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    wallet = Wallet(attach_to=node_under_test)
    transaction1 = wallet.api.create_account('initminer', 'main-account', '', broadcast=False)
    transaction2 = wallet.api.create_account('initminer', 'fork-account', '', broadcast=False)

    make_fork(
        world,
        main_chain_trxs = [transaction1],
        fork_chain_trxs = [transaction2],
    )

    # THEN
    session.query(accounts_reversible).filter(accounts_reversible.name == 'fork-account').one()
    after_fork_block = back_from_fork(world)
    wait_for_irreversible_progress(node_under_test, after_fork_block)

    session.query(accounts).filter(accounts.name == 'main-account').one()
    acc = session.query(accounts).filter(accounts.name == 'fork-account').all()
    assert acc == []
