import test_tools as tt

from haf_local_tools import create_app
from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround
from haf_local_tools.system.haf import (connect_nodes, assert_index_exists, register_index_dependency)
import time

from sqlalchemy.sql import text

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

    session.execute(text("CREATE EXTENSION IF NOT EXISTS btree_gin"))

    register_index_dependency(haf_node, 'application',
            r"CREATE INDEX IF NOT EXISTS hive_operations_vote_author_permlink ON hafd.operations USING gin"
            r"("
            r"    jsonb_extract_path_text(body_value, 'value', 'author'),"
            r"    jsonb_extract_path_text(body_value, 'value', 'permlink')"
            r")"
            r"WHERE op_type_id = 0")
    session.commit()

    # Diagnostic: check environment before polling
    has_tsdb = session.execute(text("SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'timescaledb')")).scalar()
    tt.logger.info(f"TimescaleDB extension present: {has_tsdb}")

    ops_relkind = session.execute(text(
        "SELECT c.relkind FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace "
        "WHERE n.nspname = 'hafd' AND c.relname = 'operations'"
    )).scalar()
    tt.logger.info(f"hafd.operations relkind: {ops_relkind} (p=partitioned/hypertable, r=regular)")

    # THEN
    poll_count = 0
    while True:
        result = session.execute(text("SELECT hive.check_if_registered_indexes_created('application')")).scalar()
        if result:
            break
        poll_count += 1

        # Log index status every iteration
        idx_rows = session.execute(text(
            "SELECT index_constraint_name, status, command "
            "FROM hafd.indexes_constraints "
            "WHERE table_name = 'hafd.operations'"
        )).fetchall()
        for row in idx_rows:
            tt.logger.info(f"  indexes_constraints: name={row[0]}, status={row[1]}, cmd={row[2][:80]}...")

        # Log what the hived_index connection is doing
        activity = session.execute(text(
            "SELECT pid, state, wait_event_type, wait_event, query "
            "FROM pg_stat_activity "
            "WHERE application_name = 'hived_index'"
        )).fetchall()
        if activity:
            for row in activity:
                tt.logger.info(f"  hived_index activity: pid={row[0]}, state={row[1]}, "
                             f"wait={row[2]}/{row[3]}, query={row[4][:120]}...")
        else:
            tt.logger.info("  No hived_index connections found in pg_stat_activity")

        # Also check for any errors in pg_stat_activity from haf_maintainer
        maint_activity = session.execute(text(
            "SELECT pid, state, wait_event_type, wait_event, left(query, 120) as q "
            "FROM pg_stat_activity "
            "WHERE usename = 'haf_maintainer' AND application_name LIKE '%hived%'"
        )).fetchall()
        for row in maint_activity:
            tt.logger.info(f"  haf_maintainer activity: pid={row[0]}, state={row[1]}, "
                         f"wait={row[2]}/{row[3]}, query={row[4]}...")

        tt.logger.info(f"Indexes not yet created (poll #{poll_count}). Sleeping for 10 seconds...")
        time.sleep(10)

    assert_index_exists(session, 'hafd', 'operations', 'hive_operations_vote_author_permlink')
