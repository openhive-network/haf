import pytest

from haf_local_tools.system.haf import (
    assert_are_blocks_sync_with_haf_db,
    assert_are_indexes_restored,
    assert_is_transaction_in_database,
)
from haf_local_tools.system.haf.mirrornet.constants import (
    SKELETON_KEY,
    CHAIN_ID,
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
    [6000000, 1000000],
    ids=[
        "enabled_indexes",
        "disabled_indexes_in_replay",
    ],
)
def test_replay(witness_node_with_haf, block_log_5m_path, psql_index_threshold):

    witness_node_with_haf.config.psql_index_threshold = psql_index_threshold

    witness_node_with_haf.run(
        replay_from=block_log_5m_path,
        time_offset=TIMESTAMP_5M,
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID, "--skeleton-key", SKELETON_KEY],
    )

    assert_is_transaction_in_database(witness_node_with_haf, TRANSACTION_IN_1092_BLOCK)
    assert_is_transaction_in_database(witness_node_with_haf, TRANSACTION_IN_999892_BLOCK)
    assert_is_transaction_in_database(witness_node_with_haf, TRANSACTION_IN_4500000_BLOCK)
    assert_is_transaction_in_database(witness_node_with_haf, TRANSACTION_IN_4500001_BLOCK)
    assert_is_transaction_in_database(witness_node_with_haf, TRANSACTION_IN_5000000_BLOCK)

    assert_are_blocks_sync_with_haf_db(witness_node_with_haf, 5000000)
    assert_are_indexes_restored(witness_node_with_haf)
