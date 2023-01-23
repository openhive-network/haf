from __future__ import annotations

import test_tools as tt


def test_bug_with_restarting_node_after_database_query(database):
    session, Base = database('postgresql:///haf_block_log')

    operations = Base.classes.operations

    init_node = tt.InitNode()
    init_node.config.plugin.append('sql_serializer')
    init_node.config.psql_url = str(session.get_bind().url)
    init_node.close()

    ops = session.query(operations).all()

    init_node.run()
