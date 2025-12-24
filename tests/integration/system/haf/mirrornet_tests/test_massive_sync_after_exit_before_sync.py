import time
import pytest

import test_tools as tt

from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround
from haf_local_tools.system.haf import (
    connect_nodes,
    assert_are_indexes_restored,
)
from haf_local_tools.system.haf.mirrornet.constants import (
    CHAIN_ID,
    SKELETON_KEY,
)


@pytest.mark.mirrornet
def test_massive_sync(mirrornet_witness_node, haf_node, block_log_5m, mirrornet_snapshot):
    test_start = time.time()

    apply_block_log_type_to_monolithic_workaround(mirrornet_witness_node)

    step_start = time.time()
    mirrornet_witness_node.run(
        load_snapshot_from=mirrornet_snapshot,
        time_control=tt.StartTimeControl(start_time="head_block_time"),
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID, "--skeleton-key", SKELETON_KEY],
    )
    tt.logger.info(f"[TIMING] witness_node.run (with snapshot): {time.time() - step_start:.2f}s")

    head_block_time = mirrornet_witness_node.get_head_block_time()

    step_start = time.time()
    connect_nodes(mirrornet_witness_node, haf_node)
    tt.logger.info(f"[TIMING] connect_nodes: {time.time() - step_start:.2f}s")

    step_start = time.time()
    haf_node.run(
        replay_from=block_log_5m,
        time_control=tt.StartTimeControl(start_time=head_block_time),
        exit_before_synchronization=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID],
    )
    tt.logger.info(f"[TIMING] haf_node.run (replay, exit before sync): {time.time() - step_start:.2f}s")

    head_block_time = mirrornet_witness_node.get_head_block_time()

    step_start = time.time()
    haf_node.run(
        time_control=tt.StartTimeControl(start_time=head_block_time),
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID],
    )
    tt.logger.info(f"[TIMING] haf_node.run (sync only): {time.time() - step_start:.2f}s")

    step_start = time.time()
    mirrornet_witness_node.wait_number_of_blocks(10)
    tt.logger.info(f"[TIMING] wait_number_of_blocks(10): {time.time() - step_start:.2f}s")

    step_start = time.time()
    assert_are_indexes_restored(haf_node)
    tt.logger.info(f"[TIMING] assert_are_indexes_restored: {time.time() - step_start:.2f}s")

    tt.logger.info(f"[TIMING] TOTAL test_massive_sync: {time.time() - test_start:.2f}s")
