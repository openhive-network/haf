import pytest

from haf_local_tools.system.haf import (
    assert_are_blocks_sync_with_haf_db,
    assert_are_disabled_indexes_of_irreversible_called_correct,
    assert_are_indexes_restored,
    connect_nodes,
    prepare_network_with_init_node_and_haf_node,
    prepare_and_send_transactions,
)


@pytest.mark.parametrize(
    "psql_index_threshold,expected_disable_indexes_calls",
    [(2147483647, None), (100000, 1)],
    ids=["enabled_indexes", "disabled_indexes_in_p2p_sync"],
)
def test_p2p_sync(psql_index_threshold, expected_disable_indexes_calls):
    haf_node, init_node = prepare_network_with_init_node_and_haf_node()
    haf_node.config.psql_index_threshold = psql_index_threshold

    transaction_0, transaction_1 = prepare_and_send_transactions(init_node)

    connect_nodes(init_node, haf_node)
    haf_node.run(wait_for_live=True)

    head_block_num_when_live_start = haf_node.get_last_block_number()
    assert head_block_num_when_live_start > transaction_1["block_num"]

    haf_node.wait_for_transaction_in_database(transaction_0)
    haf_node.wait_for_transaction_in_database(transaction_1)

    assert_are_blocks_sync_with_haf_db(haf_node, transaction_1["block_num"])
    assert_are_disabled_indexes_of_irreversible_called_correct(
        haf_node, expected_disable_indexes_calls
    )
    assert_are_indexes_restored(haf_node)
