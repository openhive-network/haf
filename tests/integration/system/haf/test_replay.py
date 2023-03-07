from haf_local_tools import get_operations, get_operations_from_database,prepare_network_with_init_node_and_api_node,\
    prepare_and_send_transactions, verify_operation_in_haf_database
from haf_local_tools.tables import Operations


def test_replay_without_disabled_indexes(database):
    session = database('postgresql:///haf_block_log')

    api_node, init_node = prepare_network_with_init_node_and_api_node(session)
    api_node.config.psql_index_threshold = 100

    transaction_0, transaction_1 = prepare_and_send_transactions(init_node)

    api_node.run(replay_from=init_node.block_log, stop_at_block=20, wait_for_live=False)

    verify_operation_in_haf_database('account_create_operation', [transaction_0, transaction_1], session, Operations)

    operations_in_database = get_operations_from_database(session, Operations, transaction_1['block_num'])
    operations = get_operations(init_node, last_block=transaction_1['block_num'])
    assert len(operations_in_database) == len(operations)


def test_replay_with_disabled_indexes(database):
    session = database('postgresql:///haf_block_log')

    api_node, init_node = prepare_network_with_init_node_and_api_node(session)
    api_node.config.psql_index_threshold = 10

    transaction_0, transaction_1 = prepare_and_send_transactions(init_node)

    api_node.run(replay_from=init_node.block_log, stop_at_block=20, wait_for_live=False)

    verify_operation_in_haf_database('account_create_operation', [transaction_0, transaction_1], session, Operations)

    operations_in_database = get_operations_from_database(session, Operations, transaction_1['block_num'])
    operations = get_operations(init_node, last_block=transaction_1['block_num'])
    assert len(operations_in_database) == len(operations)
