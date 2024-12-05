import test_tools as tt

from haf_local_tools import create_app
from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround
from haf_local_tools.system.haf import (connect_nodes, assert_index_exists, wait_till_registered_indexes_created)


def test_application_index_one(haf_node):
    tt.logger.info(f'Start test_application_index_one')

    # GIVEN
    init_node = tt.InitNode()
    apply_block_log_type_to_monolithic_workaround(init_node)
    init_node.run()

    # WHEN
    connect_nodes(init_node, haf_node)
    haf_node.run(
        wait_for_live=True
    )
    session = haf_node.session
    create_app(session, "application")

    session.execute("CREATE EXTENSION IF NOT EXISTS btree_gin")

    session.execute(
            r"SELECT hive.register_index_dependency('application', '"
            r"CREATE INDEX IF NOT EXISTS hive_operations_vote_author_permlink ON hafd.operations USING gin"
            r"("
            r"    jsonb_extract_path_text(body_binary::jsonb, ''value'', ''author''),"
            r"    jsonb_extract_path_text(body_binary::jsonb, ''value'', ''permlink'')"
            r")"
            r"WHERE hive.operation_id_to_type_id(id) = 0')")
    session.commit()

    # THEN
    wait_till_registered_indexes_created(haf_node, 'application')

    assert_index_exists(session, 'hafd', 'operations', 'hive_operations_vote_author_permlink')
