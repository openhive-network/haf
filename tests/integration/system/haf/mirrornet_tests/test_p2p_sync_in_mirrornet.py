import pytest
import time

import test_tools as tt

from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround
from haf_local_tools.system.haf import (
    connect_nodes,
    assert_are_blocks_sync_with_haf_db,
    assert_are_indexes_restored,
    assert_is_transaction_in_database,
)
from haf_local_tools.system.haf.mirrornet.constants import (
    SKELETON_KEY,
    CHAIN_ID,
    TRANSACTION_IN_1092_BLOCK,
    TRANSACTION_IN_999892_BLOCK,
)
from haf_local_tools import (
    wait_for_block_in_database,
)


@pytest.mark.mirrornet
@pytest.mark.parametrize(
    "psql_index_threshold",
    [6000000, 100000],
    ids=["enabled_indexes", "disabled_indexes_in_p2p_sync"],
)
def test_p2p_sync(
    mirrornet_witness_node, haf_node, block_log_5m, tmp_path, psql_index_threshold
):
    haf_node.config.psql_index_threshold = psql_index_threshold

    block_log_1m = block_log_5m.truncate(tmp_path, 1000000)
    apply_block_log_type_to_monolithic_workaround(mirrornet_witness_node)
    mirrornet_witness_node.run(
        replay_from=block_log_1m,
        time_control=tt.StartTimeControl(start_time="head_block_time"),
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID, "--skeleton-key", SKELETON_KEY],
    )

    head_block_time = mirrornet_witness_node.get_head_block_time()

    connect_nodes(mirrornet_witness_node, haf_node)

    haf_node.run(
        time_control=tt.StartTimeControl(start_time=head_block_time),
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID],
    )

    wait_for_block_in_database(haf_node.session, 1000000)
    assert_is_transaction_in_database(haf_node, TRANSACTION_IN_1092_BLOCK)
    assert_is_transaction_in_database(haf_node, TRANSACTION_IN_999892_BLOCK)
    assert_are_indexes_restored(haf_node)

    haf_node.close() #wait for node to flush wal and close
