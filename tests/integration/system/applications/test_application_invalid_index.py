import pytest
import sqlalchemy
import test_tools as tt

from haf_local_tools import create_app_with_live_stage
from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround
from haf_local_tools.system.haf import (connect_nodes, assert_index_exists, wait_till_registered_indexes_created, register_index_dependency)


def test_application_invalid_index(haf_node):
    tt.logger.info(f'Start test_application_invalid_index')

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
    create_app_with_live_stage(session, "app")

    session.execute("CREATE EXTENSION IF NOT EXISTS btree_gin")

    # THEN
    with pytest.raises(sqlalchemy.exc.InternalError):
        register_index_dependency(haf_node, 'app', 'live', "CREATE TABLE public.foo(x INTEGER)")
