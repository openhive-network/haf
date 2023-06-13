import pytest

import test_tools as tt

from haf_local_tools.system.haf import (
    connect_nodes,
    assert_are_blocks_sync_with_haf_db,
    assert_are_indexes_restored,
)
from haf_local_tools.system.haf.mirrornet.constants import (
    CHAIN_ID,
    SKELETON_KEY,
    TRANSACTION_IN_1092_BLOCK,
    TRANSACTION_IN_999892_BLOCK,
    TRANSACTION_IN_4500000_BLOCK,
    TRANSACTION_IN_4500001_BLOCK,
    TRANSACTION_IN_5000000_BLOCK,
    TIMESTAMP_5M,
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
    mirrornet_witness_node, haf_node, block_log_5m_path, tmp_path, psql_index_threshold, snapshot_path
):
    haf_node.config.psql_index_threshold = psql_index_threshold

    block_log_5m = tt.BlockLog(block_log_5m_path)
    block_log_4_5m = block_log_5m.truncate(tmp_path, 4500000)

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
        replay_from=block_log_4_5m,
        time_offset=time_offset,
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID],
    )

    haf_node.wait_for_transaction_in_database(
        transaction=TRANSACTION_IN_1092_BLOCK, timeout=120
    )
    haf_node.wait_for_transaction_in_database(
        transaction=TRANSACTION_IN_999892_BLOCK, timeout=120
    )
    haf_node.wait_for_transaction_in_database(
        transaction=TRANSACTION_IN_4500000_BLOCK, timeout=120
    )
    haf_node.wait_for_transaction_in_database(
        transaction=TRANSACTION_IN_4500001_BLOCK, timeout=120
    )
    haf_node.wait_for_transaction_in_database(
        transaction=TRANSACTION_IN_5000000_BLOCK, timeout=120
    )

    assert_are_blocks_sync_with_haf_db(haf_node, 5000000)
    assert_are_indexes_restored(haf_node)
