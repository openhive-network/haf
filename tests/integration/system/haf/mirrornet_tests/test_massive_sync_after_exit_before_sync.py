import pytest

import test_tools as tt

from haf_local_tools.system.haf import (
    connect_nodes,
    assert_are_indexes_restored,
)
from haf_local_tools.system.haf.mirrornet.constants import (
    CHAIN_ID,
    SKELETON_KEY,
)


@pytest.mark.mirrornet
def test_massive_sync(
    mirrornet_witness_node, haf_node, block_log_5m, snapshot_path
):

    mirrornet_witness_node.run(
        load_snapshot_from=snapshot_path,
        time_control=tt.StartTimeControl(start_time="head_block_time"),
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID, "--skeleton-key", SKELETON_KEY],
    )

    head_block_time = mirrornet_witness_node.get_head_block_time()

    connect_nodes(mirrornet_witness_node, haf_node)

    haf_node.run(
        replay_from=block_log_5m,
        time_control=tt.StartTimeControl(start_time=head_block_time),
        exit_before_synchronization=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID],
    )

    head_block_time = mirrornet_witness_node.get_head_block_time()

    haf_node.run(
        time_control=tt.StartTimeControl(start_time=head_block_time),
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID],
    )

    mirrornet_witness_node.wait_number_of_blocks(10)

    assert_are_indexes_restored(haf_node)
