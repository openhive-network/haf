import pytest

from haf_local_tools import connect_nodes, get_operations, get_operations_from_database, \
    prepare_network_with_init_node_and_api_node, prepare_and_send_transactions, verify_operation_in_haf_database
from haf_local_tools.tables import Operations


@pytest.mark.parametrize("psql_index_threshold", [2147483647, 100000])
def test_p2p_sync(database, psql_index_threshold):
    session = database('postgresql:///haf_block_log')

    api_node, init_node = prepare_network_with_init_node_and_api_node(session)
    api_node.config.psql_index_threshold = psql_index_threshold

    transaction_0, transaction_1 = prepare_and_send_transactions(init_node)

    connect_nodes(init_node, api_node)
    api_node.run(wait_for_live=True)

    # wait for synchronize api node with haf
    head = init_node.get_last_block_number()
    api_node.wait_for_block_with_number(head)

    verify_operation_in_haf_database('account_create_operation', [transaction_0, transaction_1], session, Operations)

    operations_in_database = get_operations_from_database(session, Operations, transaction_1['block_num'])
    operations = get_operations(init_node, last_block=transaction_1['block_num'])
    assert len(operations_in_database) == len(operations)
