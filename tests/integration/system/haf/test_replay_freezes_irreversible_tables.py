import time
from datetime import timedelta

import test_tools as tt
from test_tools.__private.node import Node
from test_tools.__private.user_handles.get_implementation import get_implementation

from haf_local_tools.haf_node import HafNode
from haf_local_tools.system.haf import (
    connect_nodes,
    create_and_run_init_node_with_retry,
    prepare_and_send_transactions,
    get_truncated_block_log,
)

FROZEN_TABLES = [
    "accounts",
    "blocks",
    "operations",
    "transactions",
    "transactions_multisig",
]
# hived polls hafd.vacuum_requests every 10 seconds once it is in live sync
VACUUM_TIMEOUT_SECONDS = 180


def wait_until_frozen(haf_node: HafNode) -> None:
    deadline = time.monotonic() + VACUUM_TIMEOUT_SECONDS
    while True:
        haf_node.session.commit()
        rows = dict(
            haf_node.query_all(
                "SELECT table_name, status::text FROM hafd.vacuum_requests WHERE schema_name = 'hafd' AND kind = 'freeze'"
            )
        )
        assert "failed" not in rows.values(), f"freeze of hafd tables failed: {rows}"
        if all(rows.get(table) == "vacuumed" for table in FROZEN_TABLES):
            return
        assert time.monotonic() < deadline, (
            f"freeze of hafd tables did not finish: {rows}"
        )
        time.sleep(1)


def test_replay_freezes_irreversible_tables(haf_node: HafNode) -> None:
    # GIVEN
    init_node = create_and_run_init_node_with_retry()
    haf_node.config.psql_index_threshold = 10
    transaction_0, _ = prepare_and_send_transactions(init_node)

    node_impl = get_implementation(init_node, Node)
    with node_impl.update_settings() as settings:
        settings.close_timeout = timedelta(seconds=30)
    init_node.close()
    block_log = get_truncated_block_log(init_node, transaction_0["block_num"] + 1)

    init_node.run()
    connect_nodes(init_node, haf_node)

    # WHEN
    haf_node.run(replay_from=block_log, wait_for_live=True)
    wait_until_frozen(haf_node)

    # THEN
    for table in FROZEN_TABLES:
        relpages, relallvisible = haf_node.query_row(
            "SELECT relpages, relallvisible FROM pg_class WHERE oid = (:name)::regclass",
            name=f"hafd.{table}",
        )
        tt.logger.info(
            f"hafd.{table}: relpages={relpages} relallvisible={relallvisible}"
        )
        # live sync keeps inserting blocks while the freeze runs, which can leave the last page out
        assert relallvisible >= relpages - 1, (
            f"hafd.{table} should be all-visible after its freeze"
        )

    scale_factors = dict(
        haf_node.query_all(
            "SELECT relname::text, opt FROM pg_class, unnest(reloptions) AS opt "
            "WHERE relnamespace = 'hafd'::regnamespace AND opt LIKE 'autovacuum_vacuum_insert_scale_factor=%'"
        )
    )
    for table in ["account_operations", "blocks", "operations", "transactions"]:
        assert (
            scale_factors.get(table) == "autovacuum_vacuum_insert_scale_factor=0.005"
        ), scale_factors
