import time
import pytest

import test_tools as tt

from conftest import log_timing
from haf_local_tools.haf_node.monolithic_workaround import (
    apply_block_log_type_to_monolithic_workaround,
)
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
    mirrornet_witness_node,
    haf_node,
    block_log,
    mirrornet_block_count,
    mirrornet_snapshot,
    request,
):
    test_name = request.node.name

    apply_block_log_type_to_monolithic_workaround(mirrornet_witness_node)

    step_start = time.time()
    # For 5M blocks, use snapshot. For fewer blocks, replay from block_log.
    if mirrornet_block_count >= 5_000_000:
        mirrornet_witness_node.run(
            load_snapshot_from=mirrornet_snapshot,
            time_control=tt.StartTimeControl(start_time="head_block_time"),
            wait_for_live=True,
            timeout=3600,
            arguments=["--chain-id", CHAIN_ID, "--skeleton-key", SKELETON_KEY],
        )
        log_timing(
            test_name, "witness_node.run (with snapshot)", time.time() - step_start
        )
    else:
        mirrornet_witness_node.run(
            replay_from=block_log,
            time_control=tt.StartTimeControl(start_time="head_block_time"),
            wait_for_live=True,
            timeout=3600,
            arguments=["--chain-id", CHAIN_ID, "--skeleton-key", SKELETON_KEY],
        )
        log_timing(test_name, "witness_node.run (replay)", time.time() - step_start)

    head_block_time = mirrornet_witness_node.get_head_block_time()

    step_start = time.time()
    connect_nodes(mirrornet_witness_node, haf_node)
    log_timing(test_name, "connect_nodes", time.time() - step_start)

    step_start = time.time()
    haf_node.run(
        replay_from=block_log,
        time_control=tt.StartTimeControl(start_time=head_block_time),
        exit_before_synchronization=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID],
    )
    log_timing(
        test_name, "haf_node.run (replay, exit before sync)", time.time() - step_start
    )

    head_block_time = mirrornet_witness_node.get_head_block_time()

    step_start = time.time()
    haf_node.run(
        time_control=tt.StartTimeControl(start_time=head_block_time),
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID],
    )
    log_timing(test_name, "haf_node.run (sync only)", time.time() - step_start)

    step_start = time.time()
    mirrornet_witness_node.wait_number_of_blocks(10)
    log_timing(test_name, "wait_number_of_blocks(10)", time.time() - step_start)

    step_start = time.time()
    assert_are_indexes_restored(haf_node)
    log_timing(test_name, "assert_are_indexes_restored", time.time() - step_start)
