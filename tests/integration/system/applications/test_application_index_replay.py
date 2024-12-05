import test_tools as tt

from haf_local_tools import create_app
from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround
from haf_local_tools.haf_node.fixtures import haf_node
from haf_local_tools.system.haf import connect_nodes

import time


def test_application_index_replay(haf_node):
    tt.logger.info(f'Start test_application_index_replay')

    # GIVEN
    init_node = tt.InitNode()
    apply_block_log_type_to_monolithic_workaround(init_node)
    init_node.run()

    haf_node.config.psql_index_threshold = 1

    # WHEN
    connect_nodes(init_node, haf_node)
    init_node.wait_for_block_with_number(25)
    haf_node.run(
        exit_at_block=2,
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

    assert not session.execute("""
    SELECT 1
    FROM pg_index i
    JOIN pg_class idx ON i.indexrelid = idx.oid
    JOIN pg_class tbl ON i.indrelid = tbl.oid
    JOIN pg_namespace n ON tbl.relnamespace = n.oid
    WHERE n.nspname = 'hafd'
    AND tbl.relname = 'operations'
    AND idx.relname = 'hive_operations_vote_author_permlink'
    """).fetchone()

    haf_node.run(
        exit_at_block=5,
    )

    # THEN
    assert not session.execute("""
    SELECT 1
    FROM pg_index i
    JOIN pg_class idx ON i.indexrelid = idx.oid
    JOIN pg_class tbl ON i.indrelid = tbl.oid
    JOIN pg_namespace n ON tbl.relnamespace = n.oid
    WHERE n.nspname = 'hafd'
    AND tbl.relname = 'operations'
    AND idx.relname = 'hive_operations_vote_author_permlink'
    """).fetchone()
