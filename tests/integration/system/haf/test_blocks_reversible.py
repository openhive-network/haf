from pathlib import Path
import unittest

from test_tools import logger
from local_tools import make_fork, back_from_fork, wait_for_irreversible_progress, run_networks
from tables import BlocksReversible


START_TEST_BLOCK = 111


def test_blocks_reversible(world_with_witnesses_and_database):
    logger.info(f'Start test_blocks_reversible')

    # GIVEN
    world, session = world_with_witnesses_and_database
    run_networks(world, Path().resolve())

    node_under_test = world.network('Beta').node('NodeUnderTest')

    # WHEN
    make_fork(world, at_block = START_TEST_BLOCK,)

    # THEN
    after_fork_block = back_from_fork(world)
    irreversible_block_num, head_block_number = wait_for_irreversible_progress(node_under_test, after_fork_block+1)

    blks = session.query(BlocksReversible).order_by(BlocksReversible.num).all()
    block_nums_reversible = [block.num for block in blks]
    case = unittest.TestCase()
    case.assertCountEqual(block_nums_reversible, range(irreversible_block_num, head_block_number+1))
