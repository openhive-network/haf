import os
from itertools import groupby
from typing import Any

import test_tools as tt

from haf_local_tools.haf_node import HafNode
from haf_local_tools.system.haf import (
    assert_are_blocks_sync_with_haf_db,
    assert_are_indexes_restored,
    create_and_run_init_node_with_retry,
    prepare_and_send_transactions,
)

ROW_CHECKSUMS = {
    "blocks": "SELECT md5(t::text) FROM hafd.blocks t ORDER BY t.num",
    "transactions": "SELECT md5(t::text) FROM hafd.transactions t ORDER BY t.block_num, t.trx_in_block",
    "operations": "SELECT md5(t::text) FROM hafd.operations t ORDER BY t.id",
    "account_operations": "SELECT md5(t::text) FROM hafd.account_operations t ORDER BY t.account_id, t.account_op_seq_no",
}

PK_AND_UNIQUE_DEFINITIONS = """
SELECT conrelid::regclass::text, conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE connamespace = 'hafd'::regnamespace AND contype IN ('p', 'u')
ORDER BY 1, 2
"""

CORE_INDEX_DEFINITIONS = """
SELECT ic.table_name, ic.index_constraint_name, ic.massive_sync_class, ic.status::text, i.indexdef
FROM hafd.indexes_constraints ic
LEFT JOIN pg_indexes i ON i.schemaname || '.' || i.tablename = ic.table_name AND i.indexname = ic.index_constraint_name
WHERE ic.massive_sync_class IS NOT NULL
ORDER BY 1, 2
"""

# hived's own connections change hafd.indexes_constraints when a massive sync drops and restores the
# core indexes, so a statement trigger there sees every readiness state the replay passes through
RECORD_READINESS = """
CREATE TABLE public.readiness_log(
    id SERIAL PRIMARY KEY,
    ready_for_block_processing BOOLEAN NOT NULL,
    ready BOOLEAN NOT NULL,
    created_deferred_indexes BIGINT NOT NULL
);

CREATE FUNCTION public.record_readiness() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public
AS $$
BEGIN
    INSERT INTO public.readiness_log( ready_for_block_processing, ready, created_deferred_indexes )
    SELECT hive.is_instance_ready_for_block_processing()
         , hive.is_instance_ready()
         , ( SELECT COUNT(*) FROM hafd.indexes_constraints WHERE massive_sync_class = 'defer' AND status = 'created' );
    RETURN NULL;
END
$$;

CREATE TRIGGER record_readiness AFTER INSERT OR UPDATE OR DELETE ON hafd.indexes_constraints
FOR EACH STATEMENT EXECUTE FUNCTION public.record_readiness();
"""


class _NodeArgumentsWithIndexPolicy(tt.NodeArguments):
    # test-tools' NodeConfig has no member for the option, so it goes to hived on the command line
    psql_massive_index_policy: str | None = None


def replay(
    haf_node: HafNode,
    init_node: tt.InitNode,
    policy: str,
    transactions: list[dict[str, Any]],
) -> None:
    haf_node.config.psql_index_threshold = 3
    haf_node.query_no_return(RECORD_READINESS)
    haf_node.run(
        replay_from=init_node.block_log,
        stop_at_block=transactions[-1]["block_num"],
        wait_for_live=False,
        arguments=_NodeArgumentsWithIndexPolicy(psql_massive_index_policy=policy),
    )
    for transaction in transactions:
        haf_node.wait_for_transaction_in_database(transaction)

    log = (haf_node.directory / "stderr.log").read_text(errors="replace")
    assert f"Indexes will be dropped with policy {policy}." in log, (
        f"hived did not run the massive sync with policy {policy}"
    )
    tt.logger.info(f"{haf_node} replayed with psql-massive-index-policy = {policy}")


def readiness_log(haf_node: HafNode) -> list[tuple[bool, bool, int]]:
    return [
        tuple(row)
        for row in haf_node.query_all(
            "SELECT ready_for_block_processing, ready, created_deferred_indexes FROM public.readiness_log ORDER BY id"
        )
    ]


def first_index(log: list[tuple[bool, bool, int]], column: int) -> int:
    return next(position for position, state in enumerate(log) if state[column])


def data_of(haf_node: HafNode) -> dict[str, Any]:
    data: dict[str, Any] = {
        table: haf_node.query_col(query) for table, query in ROW_CHECKSUMS.items()
    }
    for table in ROW_CHECKSUMS:
        data[f"{table}_count"] = haf_node.query_one(
            f"SELECT COUNT(*) FROM hafd.{table}"
        )
    data["pk_and_unique"] = [
        tuple(row) for row in haf_node.query_all(PK_AND_UNIQUE_DEFINITIONS)
    ]
    data["core_indexes"] = [
        tuple(row) for row in haf_node.query_all(CORE_INDEX_DEFINITIONS)
    ]
    return data


def test_replay_with_keep_monotonic_equals_drop_all(haf_node: HafNode) -> None:
    init_node = create_and_run_init_node_with_retry()
    transactions = list(prepare_and_send_transactions(init_node))
    last_block = transactions[-1]["block_num"]

    keep_monotonic_node = HafNode(
        database_url=os.getenv("DB_URL") or HafNode.DEFAULT_DATABASE_URL
    )

    replay(haf_node, init_node, "drop-all", transactions)
    replay(keep_monotonic_node, init_node, "keep-monotonic", transactions)

    for node in (haf_node, keep_monotonic_node):
        assert_are_blocks_sync_with_haf_db(node, last_block)
        assert_are_indexes_restored(node)
        assert node.query_one("SELECT hive.is_instance_ready()")
        assert node.query_one("SELECT hive.is_instance_ready_for_block_processing()")

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

    log = readiness_log(keep_monotonic_node)
    runs = [(state, len(list(group))) for state, group in groupby(log)]
    tt.logger.info(
        f"keep-monotonic readiness ((ready_for_block_processing, ready, created deferred indexes), statements): {runs}"
    )
    assert (True, False, 0) in log, (
        "keep-monotonic must allow block processing while no deferred index exists"
    )
    assert first_index(log, 0) < first_index(log, 1)
    assert log[-1][:2] == (True, True)

    drop_all_data = data_of(haf_node)
    counts = {
        key: value for key, value in drop_all_data.items() if key.endswith("_count")
    }
    tt.logger.info(f"drop-all replay row counts: {counts}")
    assert drop_all_data["account_operations_count"] > 0
    assert all(
        row[3] == "created" and row[4] is not None
        for row in drop_all_data["core_indexes"]
    )
    keep_monotonic_data = data_of(keep_monotonic_node)
    for key, value in drop_all_data.items():
        assert keep_monotonic_data[key] == value, (
            f"keep-monotonic replay differs from drop-all in {key}"
        )

    keep_monotonic_node.close()
