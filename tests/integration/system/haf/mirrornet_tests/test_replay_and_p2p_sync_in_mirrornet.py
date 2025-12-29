import time
import pytest

import test_tools as tt

from conftest import log_timing
from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround
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
    mirrornet_witness_node, haf_node, block_log_5m, tmp_path, psql_index_threshold, mirrornet_snapshot, request
):
    # Use pytest's node name so it matches the hook for timing output
    test_name = request.node.name
    haf_node.config.psql_index_threshold = psql_index_threshold

    step_start = time.time()
    block_log_4_5m = block_log_5m.truncate(tmp_path, 4500000)
    log_timing(test_name, "block_log truncate", time.time() - step_start)

    apply_block_log_type_to_monolithic_workaround(mirrornet_witness_node)

    step_start = time.time()
    mirrornet_witness_node.run(
        load_snapshot_from=mirrornet_snapshot,
        time_control=tt.StartTimeControl(start_time="head_block_time"),
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID, "--skeleton-key", SKELETON_KEY],
    )
    log_timing(test_name, "witness_node.run (with snapshot)", time.time() - step_start)

    head_block_time = mirrornet_witness_node.get_head_block_time()

    step_start = time.time()
    connect_nodes(mirrornet_witness_node, haf_node)
    log_timing(test_name, "connect_nodes", time.time() - step_start)

    step_start = time.time()
    haf_node.run(
        replay_from=block_log_4_5m,
        time_control=tt.StartTimeControl(start_time=head_block_time),
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID],
    )
    log_timing(test_name, "haf_node.run (replay + sync)", time.time() - step_start)

    step_start = time.time()
    # Verify transactions are properly indexed by checking blocks known to contain transactions
    assert_transaction_exists_in_block(haf_node, 1092)
    assert_transaction_exists_in_block(haf_node, 999892)
    assert_transaction_exists_in_block(haf_node, 4500000)
    assert_transaction_exists_in_block(haf_node, 4500001)
    assert_transaction_exists_in_block(haf_node, 5000000)
    log_timing(test_name, "transaction assertions", time.time() - step_start)

    step_start = time.time()
    assert_are_blocks_sync_with_haf_db(haf_node, 5000000)
    log_timing(test_name, "assert_are_blocks_sync_with_haf_db", time.time() - step_start)

    step_start = time.time()
    assert_are_indexes_restored(haf_node)
    log_timing(test_name, "assert_are_indexes_restored", time.time() - step_start)
