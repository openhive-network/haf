from __future__ import annotations

from pathlib import Path

import test_tools as tt

from haf_local_tools import connect_nodes, get_operations, get_operations_from_database,\
    prepare_network_with_init_node_and_api_node, prepare_operations, verify_operation_in_haf_database
from haf_local_tools.tables import Operations


def test_replay_and_p2p_sync(database):
    session = database('postgresql:///haf_block_log')

    api_node, init_node = prepare_network_with_init_node_and_api_node(session)

    wallet = tt.Wallet(attach_to=init_node)

    transaction_0, transaction_1 = prepare_operations(init_node, wallet)

    init_node.close()

    output_block_log_path = Path(__file__).parent / "block_log"
    output_block_log_artifacts_path = Path(__file__).parent / "block_log.artifacts"
    output_block_log_path.unlink(missing_ok=True)
    output_block_log_artifacts_path.unlink(missing_ok=True)
    block_log = init_node.block_log.truncate(Path(__file__).parent, transaction_0['block_num']+2)

    init_node.run()
    connect_nodes(init_node, api_node)

    api_node.run(replay_from=block_log, wait_for_live=True)

    #wait for synchronize api node with haf
    init_node.wait_number_of_blocks(3)

    verify_operation_in_haf_database('account_create_operation', [transaction_0, transaction_1], session, Operations)

    operations_in_database = get_operations_from_database(session, Operations, transaction_1['block_num'])
    operations = get_operations(init_node, last_block=transaction_1['block_num'])
    assert len(operations_in_database) == len(operations)


def test_replay_and_p2p_massive_sync(database):
    session = database('postgresql:///haf_block_log')

    api_node, init_node = prepare_network_with_init_node_and_api_node(session)
    api_node.config.psql_index_threshold = 10

    wallet = tt.Wallet(attach_to=init_node)

    transaction_0, transaction_1 = prepare_operations(init_node, wallet)

    init_node.close()

    output_block_log_path = Path(__file__).parent / "block_log"
    output_block_log_artifacts_path = Path(__file__).parent / "block_log.artifacts"
    output_block_log_path.unlink(missing_ok=True)
    output_block_log_artifacts_path.unlink(missing_ok=True)
    block_log = init_node.block_log.truncate(Path(__file__).parent, transaction_0['block_num']+2)

    init_node.run()
    connect_nodes(init_node, api_node)

    api_node.run(replay_from=block_log, wait_for_live=True)

    #wait for synchronize api node with haf
    init_node.wait_number_of_blocks(3)

    verify_operation_in_haf_database('account_create_operation', [transaction_0, transaction_1], session, Operations)

    operations_in_database = get_operations_from_database(session, Operations, transaction_1['block_num'])
    operations = get_operations(init_node, last_block=transaction_1['block_num'])
    assert len(operations_in_database) == len(operations)
