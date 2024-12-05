import test_tools as tt

from haf_local_tools import create_app
from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround
from haf_local_tools.system.haf import (connect_nodes, wait_till_registered_indexes_created)


def test_application_index_none(haf_node):
    tt.logger.info(f'Start test_application_index_none')

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
    # no indices created

    # THEN
    wait_till_registered_indexes_created(haf_node, 'application')
    # wait_till_registered_indexes_created returns
