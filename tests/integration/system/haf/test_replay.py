import pytest

from haf_local_tools import prepare_network_with_init_node_and_api_node, prepare_and_send_transactions, verify_operation_in_haf_database
from haf_local_tools.tables import Blocks, Operations


@pytest.mark.parametrize("psql_index_threshold", [100, 10])
def test_replay_without_disabled_indexes(database, psql_index_threshold):
    session = database('postgresql:///haf_block_log')

    api_node, init_node = prepare_network_with_init_node_and_api_node(session)
    api_node.config.psql_index_threshold = psql_index_threshold

    transaction_0, transaction_1 = prepare_and_send_transactions(init_node)

    api_node.run(replay_from=init_node.block_log, stop_at_block=20, wait_for_live=False)

    verify_operation_in_haf_database('account_create_operation', [transaction_0, transaction_1], session, Operations)

    blocks_in_database = session.query(Blocks).filter(Blocks.num <= transaction_1['block_num']).all()
    expected_blocks = transaction_1['block_num']
    assert len(blocks_in_database) == expected_blocks
