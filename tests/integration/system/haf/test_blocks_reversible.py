from pathlib import Path
import unittest

from test_tools import logger
from local_tools import make_fork, back_from_fork, wait_for_irreversible_progress, run_networks


START_TEST_BLOCK = 108


def test_blocks_reversible(world_with_witnesses_and_database):
    logger.info(f'Start test_blocks_reversible')

    # GIVEN
    world, session, Base = world_with_witnesses_and_database
    node_under_test = world.network('Beta').node('NodeUnderTest')
    blocks_reversible = Base.classes.blocks_reversible

    # WHEN
    run_networks(world, Path().resolve())
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    make_fork(world)
    after_fork_block = back_from_fork(world)

    # THEN
    irreversible_block_num, head_block_number = wait_for_irreversible_progress(node_under_test, after_fork_block+1)

    blks = session.query(blocks_reversible).order_by(blocks_reversible.num).all()
    block_nums_reversible = [block.num for block in blks]
    case = unittest.TestCase()
    case.assertCountEqual(block_nums_reversible, range(irreversible_block_num, head_block_number+1))
