import pytest

import test_tools as tt
from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround
from haf_local_tools.system.haf import (
    assert_are_blocks_sync_with_haf_db,
    assert_are_indexes_restored,
    assert_transaction_exists_in_block,
)
from haf_local_tools.system.haf.mirrornet.constants import (
    SKELETON_KEY,
    CHAIN_ID,
)


@pytest.mark.mirrornet
@pytest.mark.parametrize(
    "psql_index_threshold",
    [6000000, 1000000],
    ids=[
        "enabled_indexes",
        "disabled_indexes_in_replay",
    ],
)
def test_replay(witness_node_with_haf, block_log_5m, psql_index_threshold):
    witness_node_with_haf.config.psql_index_threshold = psql_index_threshold

    apply_block_log_type_to_monolithic_workaround(witness_node_with_haf)
    witness_node_with_haf.run(
        replay_from=block_log_5m,
        time_control=tt.StartTimeControl(start_time="head_block_time"),
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID, "--skeleton-key", SKELETON_KEY],
    )

    # Verify transactions are properly indexed by checking blocks known to contain transactions
    assert_transaction_exists_in_block(witness_node_with_haf, 1092)
    assert_transaction_exists_in_block(witness_node_with_haf, 999892)
    assert_transaction_exists_in_block(witness_node_with_haf, 4500000)
    assert_transaction_exists_in_block(witness_node_with_haf, 4500001)
    assert_transaction_exists_in_block(witness_node_with_haf, 5000000)

    assert_are_blocks_sync_with_haf_db(witness_node_with_haf, 5000000)
    assert_are_indexes_restored(witness_node_with_haf)
