import pytest

from haf_local_tools import prepare_network_with_init_node_and_api_node, prepare_and_send_transactions, verify_operation_in_haf_database
from haf_local_tools.tables import Blocks, Operations


@pytest.mark.parametrize(
    "psql_index_threshold,expected_disable_indexes_calls",
    [(100, None), (10, (1,))]
)
def test_replay_without_disabled_indexes(database, psql_index_threshold, expected_disable_indexes_calls):
    session = database('postgresql:///haf_block_log')
    session.execute( 'CREATE EXTENSION pg_stat_statements;' )
    session.commit()

    api_node, init_node = prepare_network_with_init_node_and_api_node(session)
    api_node.config.psql_index_threshold = psql_index_threshold

    transaction_0, transaction_1 = prepare_and_send_transactions(init_node)

    api_node.run(replay_from=init_node.block_log, stop_at_block=20, wait_for_live=False)

    verify_operation_in_haf_database('account_create_operation', [transaction_0, transaction_1], session, Operations)

    blocks_in_database = session.query(Blocks).filter(Blocks.num <= transaction_1['block_num']).all()
    expected_blocks = transaction_1['block_num']
    assert len(blocks_in_database) == expected_blocks

    # verify that disable_indexes_of_irreversible was called as expected
    function_calls = session.execute( "SELECT calls FROM pg_stat_user_functions WHERE funcname = 'disable_indexes_of_irreversible';" ).one_or_none()
    assert function_calls == expected_disable_indexes_calls

    # verify that indexes are restored
    indexes = session.execute( "SELECT indexname FROM pg_indexes WHERE tablename='blocks'" ).all()
    assert len(indexes) > 0
