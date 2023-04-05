import pytest

from haf_local_tools import connect_nodes, prepare_network_with_init_node_and_haf_node, prepare_and_send_transactions
from haf_local_tools.tables import Blocks


@pytest.mark.parametrize(
    "psql_index_threshold,expected_disable_indexes_calls",
    [(2147483647, None), (100000, (1,))]
)
def test_p2p_sync(database, psql_index_threshold, expected_disable_indexes_calls):
    haf_node, init_node = prepare_network_with_init_node_and_haf_node()
    haf_node.config.psql_index_threshold = psql_index_threshold

    transaction_0, transaction_1 = prepare_and_send_transactions(init_node)

    connect_nodes(init_node, haf_node)
    haf_node.run(wait_for_live=True)
    session = haf_node.session

    # wait for synchronize api node with haf
    head = init_node.get_last_block_number()
    haf_node.wait_for_block_with_number(head)

    haf_node.wait_for_transaction_in_database(transaction_0)
    haf_node.wait_for_transaction_in_database(transaction_1)

    blocks_in_database = session.query(Blocks).filter(Blocks.num <= transaction_1['block_num']).all()
    expected_blocks = transaction_1['block_num']
    assert len(blocks_in_database) == expected_blocks

    # verify that disable_indexes_of_irreversible was called as expected
    function_calls = session.execute( "SELECT calls FROM pg_stat_user_functions WHERE funcname = 'disable_indexes_of_irreversible';" ).one_or_none()
    assert function_calls == expected_disable_indexes_calls

    # verify that indexes are restored
    indexes = session.execute( "SELECT indexname FROM pg_indexes WHERE tablename='blocks'" ).all()
    assert len(indexes) > 0
