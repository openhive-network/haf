import pytest

import test_tools as tt
from haf_local_tools.haf_node.monolithic_workaround import (
    apply_block_log_type_to_monolithic_workaround,
)
from haf_local_tools.system.haf import (
    assert_are_blocks_sync_with_haf_db,
    assert_are_indexes_restored,
    assert_transaction_exists_in_block,
)
from haf_local_tools.system.haf.mirrornet.constants import (
    SKELETON_KEY,
    CHAIN_ID,
)


# Blocks known to contain transactions at different block counts
BLOCKS_WITH_TRANSACTIONS = {
    1092: 1092,  # Always valid - early block
    999892: 999892,  # Valid for 1M+ blocks
    4500000: 4500000,  # Valid for 5M blocks only
    4500001: 4500001,  # Valid for 5M blocks only
    5000000: 5000000,  # Valid for 5M blocks only
}


def get_blocks_to_verify(block_count: int) -> list[int]:
    """Return list of block numbers to verify based on total block count."""
    blocks = [1092]  # Always include early block
    if block_count >= 1_000_000:
        blocks.append(999892)
    if block_count >= 5_000_000:
        blocks.extend([4500000, 4500001, 5000000])
    return blocks


@pytest.mark.mirrornet
@pytest.mark.parametrize(
    "psql_index_threshold",
    [6000000, 1000000],
    ids=[
        "enabled_indexes",
        "disabled_indexes_in_replay",
    ],
)
def test_replay(
    witness_node_with_haf, block_log, mirrornet_block_count, psql_index_threshold
):
    witness_node_with_haf.config.psql_index_threshold = psql_index_threshold

    apply_block_log_type_to_monolithic_workaround(witness_node_with_haf)
    witness_node_with_haf.run(
        replay_from=block_log,
        time_control=tt.StartTimeControl(start_time="head_block_time"),
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID, "--skeleton-key", SKELETON_KEY],
    )

    # Verify transactions are properly indexed by checking blocks known to contain transactions
    for block_num in get_blocks_to_verify(mirrornet_block_count):
        assert_transaction_exists_in_block(witness_node_with_haf, block_num)

    assert_are_blocks_sync_with_haf_db(witness_node_with_haf, mirrornet_block_count)
    assert_are_indexes_restored(witness_node_with_haf)
