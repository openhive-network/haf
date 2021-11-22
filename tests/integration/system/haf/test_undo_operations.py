import json
from pathlib import Path
from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm.exc import MultipleResultsFound

from test_tools import logger, Asset, Wallet
from local_tools import make_fork, back_from_fork, wait_for_irreversible_progress, run_networks


START_TEST_BLOCK = 108


def test_undo_operations(world_with_witnesses_and_database):
    logger.info(f'Start test_undo_operations')

    # GIVEN
    world, session, Base = world_with_witnesses_and_database
    node_under_test = world.network('Beta').node('NodeUnderTest')
    operations = Base.classes.operations
    operations_reversible = Base.classes.operations_reversible

    # WHEN
    run_networks(world, Path().resolve())
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    wallet = Wallet(attach_to=node_under_test)
    transaction = wallet.api.transfer_to_vesting('initminer', 'null', Asset.Test(1234), broadcast=False)

    fork_block = START_TEST_BLOCK
    make_fork(
        world,
        fork_chain_trxs = [transaction],
    )

    # THEN
    ops = session.query(operations_reversible).filter(operations_reversible.block_num > START_TEST_BLOCK).all()
    types = [json.loads(op.body)['type'] for op in ops]
    assert 'transfer_to_vesting_operation' in types
    logger.info(f'Found transfer_to_vesting_operation operation, this will be reverted')

    after_fork_block = back_from_fork(world)
    wait_for_irreversible_progress(node_under_test, after_fork_block)
    for i in range(fork_block, after_fork_block):
        try:
            # there should be exactly one producer_reward_operation
            session.query(operations).filter(operations.block_num == i).one()

        except MultipleResultsFound:
            logger.error(f'Multiple operations in block {i}.')
            raise
        except NoResultFound:
            logger.error(f'No producer_reward_operation in block {i}.')
            raise
