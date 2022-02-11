from pathlib import Path
import unittest

from test_tools import logger
from local_tools import make_fork, back_from_fork, wait_for_irreversible_progress, run_networks, get_head_block
from tables import Blocks, BlocksReversible


START_TEST_BLOCK = 111


def test_undo_blocks(world_with_witnesses_and_database):
    logger.info(f'Start test_undo_blocks')

    # GIVEN
    world, session = world_with_witnesses_and_database
    run_networks(world, Path().resolve())

    node_under_test = world.network('Beta').node('NodeUnderTest')

    # WHEN
    make_fork(world, at_block=START_TEST_BLOCK)

    # THEN
    head_block = get_head_block(node_under_test)
    hash_in_fork_chain = session.query(BlocksReversible).filter(BlocksReversible.num == head_block).one().hash
    logger.info(f'hash of block {head_block} in fork chain: {hash_in_fork_chain}, this should be reverted')

    after_fork_block = back_from_fork(world)

    irreversible_block_num, _ = wait_for_irreversible_progress(node_under_test, after_fork_block)
    hash_in_main_chain = session.query(Blocks).filter(Blocks.num == head_block).one().hash
    logger.info(f'hash of block {head_block} in main chain: {hash_in_main_chain}')
    assert hash_in_fork_chain != hash_in_main_chain

    blks = session.query(Blocks).filter(Blocks.num > START_TEST_BLOCK).order_by(Blocks.num).all()
    block_nums = [block.num for block in blks]
    case = unittest.TestCase()
    case.assertCountEqual(block_nums, range(START_TEST_BLOCK+1, irreversible_block_num+1))
