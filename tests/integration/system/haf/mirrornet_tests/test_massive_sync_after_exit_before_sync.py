import pytest

import test_tools as tt

from haf_local_tools.system.haf import (
    connect_nodes,
    assert_are_indexes_restored,
)
from haf_local_tools.system.haf.mirrornet.constants import (
    CHAIN_ID,
    SKELETON_KEY,
    TIMESTAMP_5M,
)


@pytest.mark.mirrornet
def test_massive_sync(
    mirrornet_witness_node, haf_node, block_log_5m_path, snapshot_path
):

    block_log_5m = tt.BlockLog(block_log_5m_path)

    mirrornet_witness_node.run(
        load_snapshot_from=snapshot_path,
        time_offset=TIMESTAMP_5M,
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID, "--skeleton-key", SKELETON_KEY],
    )

    time_offset = tt.Time.serialize(
        mirrornet_witness_node.get_head_block_time(), format_=tt.Time.TIME_OFFSET_FORMAT
    )

    connect_nodes(mirrornet_witness_node, haf_node)

    haf_node.run(
        replay_from=block_log_5m,
        time_offset=time_offset,
        exit_before_synchronization=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID],
    )

    time_offset = tt.Time.serialize(
        mirrornet_witness_node.get_head_block_time(), format_=tt.Time.TIME_OFFSET_FORMAT
    )

    haf_node.run(
        time_offset=time_offset,
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID],
    )

    mirrornet_witness_node.wait_number_of_blocks(10)

    assert_are_indexes_restored(haf_node)
