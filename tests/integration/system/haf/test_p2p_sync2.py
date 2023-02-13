from __future__ import annotations

import test_tools as tt

from haf_local_tools import connect_nodes, get_operations, get_operations_from_database, \
    prepare_network_with_init_node_and_api_node, set_time_to_offset, verify_operation_in_haf_database
from haf_local_tools.tables import Operations


def test_p2p_sync(database):
    session = database('postgresql:///haf_block_log')

    api_node, init_node = prepare_network_with_init_node_and_api_node(session)
    api_node.config.psql_index_threshold = 2147483647

    init_node.wait_for_block_with_number(5)
    wallet = tt.Wallet(attach_to=init_node)
    transaction = wallet.api.create_account('initminer', 'alice', '{}')
    init_node.wait_for_irreversible_block()

    connect_nodes(init_node, api_node)
    api_node.run(wait_for_live=True)
    assert init_node.get_last_block_number() - 1 < api_node.get_last_block_number()

    #wait for synchronize api node with haf
    init_node.wait_number_of_blocks(3)

    verify_operation_in_haf_database('account_create_operation', [transaction], session, Operations)

    operations_in_database = get_operations_from_database(session, Operations, transaction['block_num'])
    operations = get_operations(init_node, last_block=transaction['block_num'])
    assert len(operations_in_database) == len(operations)


def test_p2p_sync_with_massive_sync(database):
    session = database('postgresql:///haf_block_log')

    api_node, init_node = prepare_network_with_init_node_and_api_node(session)

    init_node.wait_for_block_with_number(5)
    wallet = tt.Wallet(attach_to=init_node)
    transaction = wallet.api.create_account('initminer', 'alice', '{}')
    init_node.wait_for_irreversible_block()

    connect_nodes(init_node, api_node)
    api_node.run(wait_for_live=True)
    assert init_node.get_last_block_number() - 1 < api_node.get_last_block_number()

    #wait for synchronize api node with haf
    init_node.wait_number_of_blocks(3)

    verify_operation_in_haf_database('account_create_operation', [transaction], session, Operations)

    operations_in_database = get_operations_from_database(session, Operations, transaction['block_num'])
    operations = get_operations(init_node, last_block=transaction['block_num'])
    assert len(operations_in_database) == len(operations)
