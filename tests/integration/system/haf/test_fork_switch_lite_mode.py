import pytest
from sqlalchemy import text

import test_tools as tt

from haf_local_tools import make_fork, wait_for_irreversible_progress
from haf_local_tools.tables import Blocks


START_TEST_BLOCK = 108


@pytest.mark.forking_only
def test_fork_switch_in_lite_mode(prepared_networks_and_database_12_8):
    """Verify HAF survives a fork switch during LIVE sync in lite (irreversible-only) mode.

    In lite mode, reversible blocks accumulate in the C++ cache until they become
    irreversible. A fork switch must clear stale cached blocks to avoid triggering
    the blocks.size() == 1 assertion in livesync_data_dumper::trigger_data_flush().
    """
    # GIVEN
    networks_builder, session = prepared_networks_and_database_12_8
    node_under_test = networks_builder.networks[1].node('ApiNode0')

    # Verify we're in lite mode
    is_lite = session.execute(text("SELECT hive.is_lite_mode()")).scalar()
    assert is_lite is True, "Expected lite (irreversible-only) mode"

    # WHEN - wait for LIVE sync then trigger a fork
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)

    tt.logger.info(f'Triggering fork at block {START_TEST_BLOCK}')
    after_fork_block = make_fork(networks_builder.networks)

    # THEN - HAF should survive the fork and continue writing irreversible blocks
    irreversible_block_num, _ = wait_for_irreversible_progress(node_under_test, after_fork_block + 1)

    blks = session.query(Blocks).filter(Blocks.num <= irreversible_block_num).order_by(Blocks.num).all()
    block_nums = [block.num for block in blks]
    assert sorted(block_nums) == list(range(1, irreversible_block_num + 1)), \
        f"Expected continuous block range 1..{irreversible_block_num}, got gaps"
