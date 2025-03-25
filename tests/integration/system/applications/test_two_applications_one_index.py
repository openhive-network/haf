import test_tools as tt

from haf_local_tools import create_app
from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround
from haf_local_tools.system.haf import (connect_nodes, assert_index_exists, wait_till_registered_indexes_created, register_index_dependency)

from sqlalchemy.sql import text

def test_two_applications_one_index(haf_node):
    tt.logger.info(f'Start test_two_applications_one_index')

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
    create_app(session, "app_1")
    create_app(session, "app_2")

    session.execute(text("CREATE EXTENSION IF NOT EXISTS btree_gin"))

    register_index_dependency(haf_node, 'app_1',
            r"CREATE INDEX IF NOT EXISTS hive_operations_author_permlink ON hafd.operations USING gin"
            r"("
            r"    jsonb_extract_path_text(body_binary::jsonb, 'value', 'author'),"
            r"    jsonb_extract_path_text(body_binary::jsonb, 'value', 'permlink')"
            r")")
    register_index_dependency(haf_node, 'app_2',
            r"CREATE INDEX IF NOT EXISTS hive_operations_author_permlink ON hafd.operations USING gin"
            r"("
            r"    jsonb_extract_path_text(body_binary::jsonb, 'value', 'author'),"
            r"    jsonb_extract_path_text(body_binary::jsonb, 'value', 'permlink')"
            r")")
    session.commit()

    # THEN
    wait_till_registered_indexes_created(haf_node, 'app_1')
    wait_till_registered_indexes_created(haf_node, 'app_2')

    assert_index_exists(session, 'hafd', 'operations', 'hive_operations_author_permlink')
