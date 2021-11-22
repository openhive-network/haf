from pathlib import Path
import unittest

from test_tools import logger
from local_tools import make_fork, back_from_fork, wait_for_irreversible_progress, run_networks, get_head_block


START_TEST_BLOCK = 108


def test_undo_blocks(world_with_witnesses_and_database):
    logger.info(f'Start test_undo_blocks')

    # GIVEN
    world, session, Base = world_with_witnesses_and_database
    node_under_test = world.network('Beta').node('NodeUnderTest')
    blocks = Base.classes.blocks
    blocks_reversible = Base.classes.blocks_reversible

    # WHEN
    run_networks(world, Path().resolve())
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    make_fork(world)

    # THEN
    head_block = get_head_block(node_under_test)
    hash_in_fork_chain = session.query(blocks_reversible).filter(blocks_reversible.num == head_block).one().hash
    logger.info(f'hash of block {head_block} in fork chain: {hash_in_fork_chain}, this should be reverted')

    after_fork_block = back_from_fork(world)

    irreversible_block_num, _ = wait_for_irreversible_progress(node_under_test, after_fork_block)
    hash_in_main_chain = session.query(blocks).filter(blocks.num == head_block).one().hash
    logger.info(f'hash of block {head_block} in main chain: {hash_in_main_chain}')
    assert hash_in_fork_chain != hash_in_main_chain

    blks = session.query(blocks).filter(blocks.num > START_TEST_BLOCK).order_by(blocks.num).all()
    block_nums = [block.num for block in blks]
    case = unittest.TestCase()
    case.assertCountEqual(block_nums, range(START_TEST_BLOCK+1, irreversible_block_num+1))
