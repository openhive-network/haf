import pytest

import test_tools as tt

from haf_local_tools.system.haf import (
    assert_are_blocks_sync_with_haf_db,
    assert_are_indexes_restored,
    connect_nodes,
    prepare_and_send_transactions,
)

def get_truncated_block_log(node, block_count: int):
    output_block_log_path = tt.context.get_current_directory() / "block_log"
    output_block_log_path.unlink(missing_ok=True)
    output_block_log_artifacts_path = (tt.context.get_current_directory() / "block_log.artifacts")
    output_block_log_artifacts_path.unlink(missing_ok=True)
    block_log = node.block_log.truncate(tt.context.get_current_directory(), block_count)
    return block_log


@pytest.mark.parametrize(
    "psql_index_threshold",
    [2147483647, 100000, 10],
    ids=[
        "enabled_indexes",
        "disabled_indexes_in_replay",
        "disabled_indexes_in_replay_and_p2p_sync",
    ],
)
def test_replay_and_p2p_sync(haf_node, psql_index_threshold):
    init_node = tt.InitNode()
    init_node.run()

    haf_node.config.psql_index_threshold = psql_index_threshold

    transaction_0, transaction_1 = prepare_and_send_transactions(init_node)

    init_node.close()
    block_log = get_truncated_block_log(init_node, transaction_0["block_num"] + 1)

    init_node.run()
    connect_nodes(init_node, haf_node)

    haf_node.run(replay_from=block_log, wait_for_live=True)

    head_block_num_when_live_start = haf_node.get_last_block_number()
    assert head_block_num_when_live_start > transaction_1["block_num"]

    haf_node.wait_for_transaction_in_database(transaction_0)
    haf_node.wait_for_transaction_in_database(transaction_1)

    assert_are_blocks_sync_with_haf_db(haf_node, transaction_1["block_num"])
    assert_are_indexes_restored(haf_node)
