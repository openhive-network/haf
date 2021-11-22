from pathlib import Path
from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm.exc import MultipleResultsFound

from test_tools import logger, Asset, Wallet, Account
from local_tools import make_fork, back_from_fork, wait_for_irreversible_progress, run_networks


START_TEST_BLOCK = 108


def test_undo_transactions_multisig(world_with_witnesses_and_database):
    logger.info(f'Start test_undo_transactions_multisig')

    # GIVEN
    world, session, Base = world_with_witnesses_and_database
    node_under_test = world.network('Beta').node('NodeUnderTest')
    transactions = Base.classes.transactions
    transactions_reversible = Base.classes.transactions_reversible
    transactions_multisig = Base.classes.transactions_multisig
    transactions_multisig_reversible = Base.classes.transactions_multisig_reversible

    # WHEN
    run_networks(world, Path().resolve())
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    wallet = Wallet(attach_to=node_under_test)
    trx1 = prepare_transaction1(wallet)
    trx2 = prepare_transaction2(wallet)

    make_fork(
        world,
        main_chain_trxs = [trx1],
        fork_chain_trxs = [trx2],
    )

    # THEN
    trx_fork = session.query(transactions_reversible).filter(transactions_reversible.block_num > START_TEST_BLOCK).one()
    trx_hash_fork = trx_fork.trx_hash
    logger.info(f'Found transaction with hash {trx_hash_fork} on block {trx_fork.block_num}, this will be reverted')
    session.query(transactions_multisig_reversible).filter(transactions_multisig_reversible.trx_hash == trx_hash_fork).one()

    after_fork_block = back_from_fork(world)
    wait_for_irreversible_progress(node_under_test, after_fork_block)
    trx_main = session.query(transactions).filter(transactions.block_num > START_TEST_BLOCK).one()
    trx_hash_main = trx_main.trx_hash
    logger.info(f'Found transaction with hash {trx_hash_main} on block {trx_main.block_num}')

    session.query(transactions_multisig).filter(transactions_multisig.trx_hash == trx_hash_main).one()
    trxs_fork = session.query(transactions_multisig).filter(transactions_multisig.trx_hash == trx_hash_fork).all()
    assert trxs_fork == []


def prepare_transaction1(wallet):
    context1 = wallet.in_single_transaction(broadcast=False)
    with context1:
        for name in ['witness1-alpha', 'witness1-beta']:
            wallet.api.transfer(name, "initminer", Asset.Test(1), 'memo')
    transaction1 = context1.get_response()
    return transaction1


def prepare_transaction2(wallet):
    context2 = wallet.in_single_transaction(broadcast=False)
    with context2:
        for name in ['witness2-alpha', 'witness2-beta']:
            wallet.api.transfer(name, "initminer", Asset.Test(1), 'memo')
    transaction2 = context2.get_response()
    return transaction2
