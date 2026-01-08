import time
import pytest

import test_tools as tt

from conftest import log_timing
from haf_local_tools.haf_node.monolithic_workaround import (
    apply_block_log_type_to_monolithic_workaround,
)
from haf_local_tools.system.haf import (
    connect_nodes,
    assert_are_blocks_sync_with_haf_db,
    assert_are_indexes_restored,
    assert_transaction_exists_in_block,
)
from haf_local_tools.system.haf.mirrornet.constants import (
    CHAIN_ID,
    SKELETON_KEY,
)


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
    [6000000, 3000000, 10],
    ids=[
        "enabled_indexes",
        "disabled_indexes_in_replay",
        "disabled_indexes_in_replay_and_p2p_sync",
    ],
)
def test_replay_and_p2p_sync(
    mirrornet_witness_node,
    haf_node,
    block_log,
    mirrornet_block_count,
    tmp_path,
    psql_index_threshold,
    mirrornet_snapshot,
    request,
):
    # Use pytest's node name so it matches the hook for timing output
    test_name = request.node.name
    haf_node.config.psql_index_threshold = psql_index_threshold

    # HAF node replays 90% of blocks and P2P syncs the remaining 10%
    haf_replay_blocks = int(mirrornet_block_count * 0.9)

    step_start = time.time()
    haf_block_log_dir = tmp_path / "haf_block_log"
    haf_block_log_dir.mkdir(exist_ok=True)
    block_log_for_haf = block_log.truncate(haf_block_log_dir, haf_replay_blocks)
    log_timing(test_name, "block_log truncate", time.time() - step_start)

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
        replay_from=block_log_for_haf,
        time_control=tt.StartTimeControl(start_time=head_block_time),
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID],
    )
    log_timing(test_name, "haf_node.run (replay + sync)", time.time() - step_start)

    # Wait for HAF to sync to the expected block count (P2P sync may still be in progress after wait_for_live)
    step_start = time.time()
    haf_node.wait_for_block_with_number(mirrornet_block_count, timeout=300)
    log_timing(test_name, "wait_for_block_with_number", time.time() - step_start)

    step_start = time.time()
    # Verify transactions are properly indexed by checking blocks known to contain transactions
    for block_num in get_blocks_to_verify(mirrornet_block_count):
        assert_transaction_exists_in_block(haf_node, block_num)
    log_timing(test_name, "transaction assertions", time.time() - step_start)

    step_start = time.time()
    assert_are_blocks_sync_with_haf_db(haf_node, mirrornet_block_count)
    log_timing(
        test_name, "assert_are_blocks_sync_with_haf_db", time.time() - step_start
    )

    step_start = time.time()
    assert_are_indexes_restored(haf_node)
    log_timing(test_name, "assert_are_indexes_restored", time.time() - step_start)
