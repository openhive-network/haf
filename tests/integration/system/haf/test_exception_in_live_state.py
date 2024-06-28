import sqlalchemy

import test_tools as tt

from haf_local_tools.system.haf import prepare_and_send_transactions, get_truncated_block_log, connect_nodes


def test_exception_in_live_state(haf_node):
    """
    Check that an exception raised in LIVE state is handled correctly.
    The node should catch the exception, kill all the workers and exit cleanly.
    """
    # generate some operations to be synchronised to
    init_node = tt.InitNode()
    init_node.run()
    transaction_0, transaction_1 = prepare_and_send_transactions(init_node)

    # Alter operations table so that worker thread raises an exception when storing data in it
    session = haf_node.session
    session.execute(sqlalchemy.text('ALTER TABLE hive.operations ADD CONSTRAINT check_length CHECK (octet_length(body_binary) <= 21)'))
    connect_nodes(init_node, haf_node)
    haf_node.config.psql_index_threshold = 1
    haf_node.run(
            wait_for_live=True,
            arguments=['--psql-livesync-threshold', '4294967295']
    )
