import pytest

from haf_local_tools.system.haf import (
    assert_are_blocks_sync_with_haf_db,
    assert_are_indexes_restored,
    prepare_network_with_init_node_and_haf_node,
    prepare_and_send_transactions,
)


@pytest.mark.parametrize(
    "psql_index_threshold",
    [100, 3,],
    ids=[
        "enabled_indexes",
        "disabled_indexes_in_replay",
    ],
)
def test_replay(psql_index_threshold):
    haf_node, init_node = prepare_network_with_init_node_and_haf_node()
    haf_node.config.psql_index_threshold = psql_index_threshold

    transaction_0, transaction_1 = prepare_and_send_transactions(init_node)

    haf_node.run(
        replay_from=init_node.block_log,
        stop_at_block=transaction_1["block_num"],
        wait_for_live=False,
    )
    session = haf_node.session

    haf_node.wait_for_transaction_in_database(transaction_0)
    haf_node.wait_for_transaction_in_database(transaction_1)

    assert_are_blocks_sync_with_haf_db(session, transaction_1["block_num"])
    assert_are_indexes_restored(haf_node)
