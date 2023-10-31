import pytest

import test_tools as tt

from haf_local_tools.system.haf import (
    assert_are_blocks_sync_with_haf_db,
    assert_are_indexes_restored,
    connect_nodes,
    prepare_and_send_transactions,
    BlocksView
)

@pytest.mark.parametrize(
    "psql_index_threshold",
    [2147483647, 100000],
    ids=["enabled_indexes", "disabled_indexes_in_p2p_sync"],
)
def test_p2p_sync_from_4(haf_node, psql_index_threshold):
    init_node = tt.InitNode()
    init_node.run()

    haf_node.config.psql_index_threshold = psql_index_threshold
    haf_node.config.psql_first_block = 4

    init_node.wait_number_of_blocks(3)

    transaction_0, transaction_1 = prepare_and_send_transactions(init_node)

    connect_nodes(init_node, haf_node)
    haf_node.run(wait_for_live=True)

    head_block_num_when_live_start = haf_node.get_last_block_number()
    assert head_block_num_when_live_start > transaction_1["block_num"]

    haf_node.wait_for_transaction_in_database(transaction_0)
    haf_node.wait_for_transaction_in_database(transaction_1)

    # syncing has started 3 block later than blockchain start block
    block_of_transaction1 = transaction_1["block_num"]
    blocks_in_database_before_transaction1 = (
        haf_node.session.query(BlocksView).filter(BlocksView.num <= block_of_transaction1).count()
    )

    tt.logger.info(f"assert_are_blocks_sync_with_haf_db actual {blocks_in_database_before_transaction1}, expected {block_of_transaction1-3}")
    assert blocks_in_database_before_transaction1 == block_of_transaction1 - 3

    assert_are_indexes_restored(haf_node)
