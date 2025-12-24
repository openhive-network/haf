import time
import pytest

import test_tools as tt

from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround
from haf_local_tools.system.haf import (
    connect_nodes,
    assert_are_blocks_sync_with_haf_db,
    assert_are_indexes_restored,
    assert_is_transaction_in_database,
)
from haf_local_tools.system.haf.mirrornet.constants import (
    CHAIN_ID,
    SKELETON_KEY,
    TRANSACTION_IN_1092_BLOCK,
    TRANSACTION_IN_999892_BLOCK,
    TRANSACTION_IN_4500000_BLOCK,
    TRANSACTION_IN_4500001_BLOCK,
    TRANSACTION_IN_5000000_BLOCK,
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
    mirrornet_witness_node, haf_node, block_log_5m, tmp_path, psql_index_threshold, mirrornet_snapshot
):
    test_start = time.time()
    haf_node.config.psql_index_threshold = psql_index_threshold

    step_start = time.time()
    block_log_4_5m = block_log_5m.truncate(tmp_path, 4500000)
    tt.logger.info(f"[TIMING] block_log truncate: {time.time() - step_start:.2f}s")

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
        replay_from=block_log_4_5m,
        time_control=tt.StartTimeControl(start_time=head_block_time),
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID],
    )
    tt.logger.info(f"[TIMING] haf_node.run (replay + sync): {time.time() - step_start:.2f}s")

    step_start = time.time()
    assert_is_transaction_in_database(haf_node, TRANSACTION_IN_1092_BLOCK)
    assert_is_transaction_in_database(haf_node, TRANSACTION_IN_999892_BLOCK)
    assert_is_transaction_in_database(haf_node, TRANSACTION_IN_4500000_BLOCK)
    assert_is_transaction_in_database(haf_node, TRANSACTION_IN_4500001_BLOCK)
    assert_is_transaction_in_database(haf_node, TRANSACTION_IN_5000000_BLOCK)
    tt.logger.info(f"[TIMING] transaction assertions: {time.time() - step_start:.2f}s")

    step_start = time.time()
    assert_are_blocks_sync_with_haf_db(haf_node, 5000000)
    tt.logger.info(f"[TIMING] assert_are_blocks_sync_with_haf_db: {time.time() - step_start:.2f}s")

    step_start = time.time()
    assert_are_indexes_restored(haf_node)
    tt.logger.info(f"[TIMING] assert_are_indexes_restored: {time.time() - step_start:.2f}s")

    tt.logger.info(f"[TIMING] TOTAL test_replay_and_p2p_sync: {time.time() - test_start:.2f}s")
