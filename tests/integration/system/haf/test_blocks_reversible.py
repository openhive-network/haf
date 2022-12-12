from pathlib import Path
import unittest

import test_tools as tt

from local_tools import make_fork, wait_for_irreversible_progress, run_networks
from tables import BlocksReversible


START_TEST_BLOCK = 108


def test_blocks_reversible(prepared_networks_and_database):
    tt.logger.info(f'Start test_blocks_reversible')

    # GIVEN
    networks, session = prepared_networks_and_database
    node_under_test = networks['Beta'].node('ApiNode0')
    #blocks_reversible = Base.classes.blocks_reversible

    # WHEN
    run_networks(networks)
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    after_fork_block = make_fork(networks)

    # THEN
    irreversible_block_num, head_block_number = wait_for_irreversible_progress(node_under_test, after_fork_block+1)

    blks = session.query(BlocksReversible).order_by(BlocksReversible.num).all()
    block_nums_reversible = [block.num for block in blks]
    case = unittest.TestCase()
    case.assertCountEqual(block_nums_reversible, range(irreversible_block_num, head_block_number))
