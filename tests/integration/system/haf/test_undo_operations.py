import json
from pathlib import Path
from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm.exc import MultipleResultsFound

from test_tools import logger, Asset, Wallet
from local_tools import make_fork, back_from_fork, wait_for_irreversible_progress, run_networks
from tables import Operations, OperationsReversible


START_TEST_BLOCK = 111


def test_undo_operations(world_with_witnesses_and_database):
    logger.info(f'Start test_undo_operations')

    # GIVEN
    world, session = world_with_witnesses_and_database
    run_networks(world, Path().resolve())

    node_under_test = world.network('Beta').node('NodeUnderTest')
    wallet = Wallet(attach_to=node_under_test)
    transaction = wallet.api.transfer_to_vesting('initminer', 'null', Asset.Test(1234), broadcast=False)

    # WHEN
    make_fork(
        world,
        at_block = START_TEST_BLOCK,
        fork_chain_trxs = [transaction],
    )

    # THEN
    ops = session.query(OperationsReversible).filter(OperationsReversible.block_num > START_TEST_BLOCK).all()
    types = [json.loads(op.body)['type'] for op in ops]
    assert 'transfer_to_vesting_operation' in types
    logger.info(f'Found transfer_to_vesting_operation operation, this will be reverted')

    after_fork_block = back_from_fork(world)
    wait_for_irreversible_progress(node_under_test, after_fork_block)
    for i in range(START_TEST_BLOCK, after_fork_block):
        try:
            # there should be exactly one producer_reward_operation
            session.query(Operations).filter(Operations.block_num == i).one()

        except MultipleResultsFound:
            logger.error(f'Multiple operations in block {i}.')
            raise
        except NoResultFound:
            logger.error(f'No producer_reward_operation in block {i}.')
            raise
