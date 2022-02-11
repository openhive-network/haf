from pathlib import Path
import json

from test_tools import logger, Asset, Wallet
from local_tools import make_fork, back_from_fork, wait_for_irreversible_progress, run_networks
from tables import Operations, Transactions


START_TEST_BLOCK = 111


def test_operations_after_switchng_fork(world_with_witnesses_and_database):
    logger.info(f'Start test_operations_after_switchng_fork')

    # GIVEN
    world, session = world_with_witnesses_and_database
    node_under_test = world.network('Beta').node('NodeUnderTest')

    # WHEN
    run_networks(world)

    node_under_test = world.network('Beta').node('NodeUnderTest')
    wallet = Wallet(attach_to=node_under_test)
    transaction1 = wallet.api.transfer('initminer', 'null', Asset.Test(1234), 'memo', broadcast=False)
    transaction2 = wallet.api.transfer_to_vesting('initminer', 'null', Asset.Test(1234), broadcast=False)

    # WHEN
    make_fork(
        world,
        at_block = START_TEST_BLOCK,
        main_chain_trxs = [transaction1],
        fork_chain_trxs = [transaction2],
    )

    # THEN
    after_fork_block = back_from_fork(world)
    wait_for_irreversible_progress(node_under_test, after_fork_block)
    trx = session.query(Transactions).filter(Transactions.block_num > START_TEST_BLOCK).one()

    ops = session.query(Operations).filter(Operations.block_num == trx.block_num).all()
    types = [json.loads(op.body)['type'] for op in ops]

    assert 'producer_reward_operation' in types
    assert 'transfer_operation' in types
    assert 'transfer_to_vesting_operation' not in types
