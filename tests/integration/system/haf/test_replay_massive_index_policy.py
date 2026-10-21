import os
from typing import Any

import test_tools as tt

from haf_local_tools.haf_node import HafNode
from haf_local_tools.haf_node.monolithic_workaround import (
    apply_block_log_type_to_monolithic_workaround,
)
from haf_local_tools.system.haf import (
    assert_are_blocks_sync_with_haf_db,
    assert_are_indexes_restored,
    create_and_run_init_node_with_retry,
    prepare_and_send_transactions,
)

CHECKSUMS = {
    "operations": "SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM hafd.operations t",
    "transactions": "SELECT md5(string_agg(t::text, '|' ORDER BY t.block_num, t.trx_in_block)) FROM hafd.transactions t",
    "account_operations": "SELECT md5(string_agg(t::text, '|' ORDER BY t.account_id, t.account_op_seq_no)) FROM hafd.account_operations t",
}


def replay(
    haf_node: HafNode,
    init_node: tt.InitNode,
    policy: str,
    transactions: list[dict[str, Any]],
) -> None:
    haf_node.config.psql_index_threshold = 3
    haf_node.config.psql_massive_index_policy = policy
    haf_node.run(
        replay_from=init_node.block_log,
        stop_at_block=transactions[-1]["block_num"],
        wait_for_live=False,
    )
    for transaction in transactions:
        haf_node.wait_for_transaction_in_database(transaction)


def data_of(haf_node: HafNode) -> dict[str, Any]:
    data = {table: haf_node.query_one(query) for table, query in CHECKSUMS.items()}
    for table in CHECKSUMS:
        data[f"{table}_count"] = haf_node.query_one(
            f"SELECT COUNT(*) FROM hafd.{table}"
        )
    return data


def test_replay_with_keep_monotonic_equals_drop_all(haf_node: HafNode) -> None:
    init_node = create_and_run_init_node_with_retry()
    transactions = list(prepare_and_send_transactions(init_node))
    last_block = transactions[-1]["block_num"]

    keep_monotonic_node = HafNode(
        name="HafNodeKeepMonotonic",
        database_url=os.getenv("DB_URL") or HafNode.DEFAULT_DATABASE_URL,
    )
    apply_block_log_type_to_monolithic_workaround(keep_monotonic_node)

    replay(haf_node, init_node, "drop-all", transactions)
    replay(keep_monotonic_node, init_node, "keep-monotonic", transactions)

    for node in (haf_node, keep_monotonic_node):
        assert_are_blocks_sync_with_haf_db(node, last_block)
        assert_are_indexes_restored(node)
        assert node.query_one("SELECT hive.is_instance_ready()")
        assert node.query_one("SELECT hive.is_instance_ready_for_block_processing()")

    # the class is recorded whichever policy dropped the indexes
    for node in (haf_node, keep_monotonic_node):
        classes = dict(
            node.query_all(
                "SELECT index_constraint_name, massive_sync_class FROM hafd.indexes_constraints"
                " WHERE table_name IN ('hafd.operations', 'hafd.transactions', 'hafd.account_operations')"
            )
        )
        assert classes["pk_hive_operations"] == "keep"
        assert classes["hive_operations_block_num_id_idx"] == "keep"
        assert classes["hive_transactions_block_num_trx_in_block_idx"] == "keep"
        assert classes["pk_hive_transactions"] == "defer"
        assert classes["hive_account_operations_uq1"] == "defer"
        assert classes["hive_operations_op_type_id_block_num"] == "defer"

    drop_all_data = data_of(haf_node)
    tt.logger.info(f"drop-all replay data: {drop_all_data}")
    assert drop_all_data["account_operations_count"] > 0
    assert data_of(keep_monotonic_node) == drop_all_data

    keep_monotonic_node.close()
