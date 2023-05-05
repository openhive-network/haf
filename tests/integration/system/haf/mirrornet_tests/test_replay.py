import pytest
import test_tools as tt

from haf_local_tools.haf_node import HafNode
from haf_local_tools.system.haf import assert_are_blocks_sync_with_haf_db, assert_are_indexes_restored
from haf_local_tools.system.haf.mirrornet import get_pytest_sleep_time
from haf_local_tools.system.haf.mirrornet.constants import (
    SKELETON_KEY,
    CHAIN_ID,
    TRANSACTION_IN_1092_BLOCK,
    TRANSACTION_IN_2999999_BLOCK,
    TRANSACTION_IN_3000001_BLOCK,
    TRANSACTION_IN_5000000_BLOCK,
    TIMESTAMP_5M,
)

@pytest.mark.parametrize(
    "psql_index_threshold",
    [6000000, 1000000],
    ids=[
        "enabled_indexes",
        "disabled_indexes_in_replay",
    ],
)
def test_replay(block_log_5m_path,tmp_path, psql_index_threshold):
    sleep_time = get_pytest_sleep_time()

    haf_node = HafNode()
    haf_node.config.shared_file_size = "2G"
    haf_node.config.psql_index_threshold = psql_index_threshold

    block_log_5m = tt.BlockLog(block_log_5m_path)
    block_log_1m = block_log_5m.truncate(tmp_path, 1000000)

    haf_node.run(
        replay_from=block_log_1m,
        time_offset=TIMESTAMP_5M,
        wait_for_live=False,
        timeout=sleep_time,
        arguments=["--chain-id", CHAIN_ID, "--skeleton-key", SKELETON_KEY],
    )

    haf_node.wait_for_transaction_in_database(transaction=TRANSACTION_IN_1092_BLOCK)
    # haf_node.wait_for_transaction_in_database(transaction=TRANSACTION_IN_2999999_BLOCK)
    # haf_node.wait_for_transaction_in_database(transaction=TRANSACTION_IN_3000001_BLOCK)
    # haf_node.wait_for_transaction_in_database(transaction=TRANSACTION_IN_5000000_BLOCK)

    # assert_are_blocks_sync_with_haf_db(haf_node.session, 5000000)
    # assert_are_indexes_restored(haf_node)
