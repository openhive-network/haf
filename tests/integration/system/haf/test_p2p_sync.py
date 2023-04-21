import pytest

from haf_local_tools.system.haf import (
    assert_are_blocks_sync_with_haf_db,
    assert_are_indexes_restored,
    connect_nodes,
    prepare_network_with_init_node_and_haf_node,
    prepare_and_send_transactions,
)


@pytest.mark.parametrize(
    "psql_index_threshold",
    [2147483647, 100000],
    ids=["enabled_indexes", "disabled_indexes_in_p2p_sync"],
)
def test_p2p_sync(psql_index_threshold):
    haf_node, init_node = prepare_network_with_init_node_and_haf_node()
    haf_node.config.psql_index_threshold = psql_index_threshold

    transaction_0, transaction_1 = prepare_and_send_transactions(init_node)

    connect_nodes(init_node, haf_node)
    haf_node.run(wait_for_live=True)
    session = haf_node.session

    haf_node.wait_for_transaction_in_database(transaction_0)
    haf_node.wait_for_transaction_in_database(transaction_1)

    assert_are_blocks_sync_with_haf_db(session, transaction_1["block_num"])
    assert_are_indexes_restored(haf_node)
