from sqlalchemy.orm import Session
from sqlalchemy.sql import text

from typing import TYPE_CHECKING, Union

import test_tools as tt

from haf_local_tools.haf_node._haf_node import HafNode, Transaction, TransactionId
from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround
from haf_local_tools.tables import BlocksView
import time


def create_and_run_init_node_with_retry(max_retries: int = 2, retry_delay: float = 1.0) -> tt.InitNode:
    """Create and run an InitNode with retry logic to handle transient startup failures in parallel test execution.

    When running tests in parallel, hived startup can occasionally fail due to port detection
    issues in beekeepy when multiple hived processes run simultaneously. This function provides
    resilience by retrying node creation on transient failures.

    Args:
        max_retries: Maximum number of retry attempts (default: 2)
        retry_delay: Delay in seconds between retries (default: 1.0)

    Returns:
        A running InitNode instance

    Raises:
        The last exception encountered if all retries are exhausted
    """
    last_error = None
    for attempt in range(max_retries + 1):
        try:
            node = tt.InitNode()
            apply_block_log_type_to_monolithic_workaround(node)
            node.run()
            return node
        except Exception as e:
            last_error = e
            if attempt < max_retries:
                tt.logger.warning(f"InitNode startup failed (attempt {attempt + 1}/{max_retries + 1}): {e}. Retrying...")
                time.sleep(retry_delay)
            else:
                raise last_error


def connect_nodes(seed_node: tt.RawNode, peer_node: tt.RawNode) -> None:
    """
    This place have to be removed after solving issue https://gitlab.syncad.com/hive/test-tools/-/issues/10
    """
    peer_node.config.p2p_seed_node.append(seed_node.p2p_endpoint)


def prepare_and_send_transactions(node: tt.InitNode) -> [dict, dict]:
    wallet = tt.Wallet(attach_to=node)
    transaction_0 = wallet.api.create_account("initminer", "alice", "{}")
    node.wait_number_of_blocks(3)
    transaction_1 = wallet.api.create_account("initminer", "bob", "{}")
    node.wait_for_irreversible_block()
    return transaction_0, transaction_1


def assert_are_blocks_sync_with_haf_db(haf_node: HafNode, limit_block_num: int) -> bool:
    blocks_in_database = (
        haf_node.session.query(BlocksView).filter(BlocksView.num <= limit_block_num).count()
    )
    tt.logger.info(f"assert_are_blocks_sync_with_haf_db actual {blocks_in_database=}, expected {limit_block_num=}")
    assert blocks_in_database == limit_block_num


def assert_are_indexes_restored(haf_node: HafNode):
    assert haf_node.query_one("SELECT hive.are_indexes_restored()")


def does_index_exist(session, namespace, table, indexname):
    return session.execute(text("""
    SELECT 1
    FROM pg_index i
    JOIN pg_class idx ON i.indexrelid = idx.oid
    JOIN pg_class tbl ON i.indrelid = tbl.oid
    JOIN pg_namespace n ON tbl.relnamespace = n.oid
    WHERE n.nspname = :ns
    AND tbl.relname = :table
    AND idx.relname = :index
    """), {'ns':namespace, 'table': table, 'index': indexname}).fetchone()


def assert_index_exists(session, namespace, table, indexname):
    assert does_index_exist(session, namespace, table, indexname)


def assert_index_does_not_exist(session, namespace, table, indexname):
    assert not does_index_exist(session, namespace, table, indexname)


def wait_till_registered_indexes_created(haf_node, context):
    while True:
        result = haf_node.session.execute(text("SELECT hive.check_if_registered_indexes_created(:ctx)"), {'ctx': context}).scalar()
        if result:
            break
        tt.logger.info("Indexes not yet created. Sleeping for 10 seconds...")
        time.sleep(10)


def register_index_dependency(haf_node, context, create_index_command):
    haf_node.session.execute(
            text("SELECT hive.register_index_dependency(:ctx, :cmd)"), {'ctx': context, 'cmd': create_index_command})


def assert_is_transaction_in_database(haf_node: HafNode, transaction:  Union[Transaction, TransactionId], timeout: float = 10):
    try:
        haf_node.wait_for_transaction_in_database(transaction=transaction, timeout=timeout)
    except TimeoutError:
        assert False, "Transaction NOT exist in database"
    return True


def assert_transaction_exists_in_block(haf_node: HafNode, block_num: int, timeout: float = 10):
    """Verify that at least one transaction exists in the specified block.

    This is more robust than checking for specific transaction hashes, as it doesn't
    depend on block_log-specific transaction IDs that may change when the mirrornet
    block_log is regenerated.
    """
    sql = "SELECT exists(SELECT 1 FROM hive.transactions_view WHERE block_num = :block_num)"
    end_time = time.time() + timeout
    while time.time() < end_time:
        result = haf_node.session.execute(text(sql), {"block_num": block_num}).scalar()
        if result:
            return True
        time.sleep(0.5)
    assert False, f"No transaction found in block {block_num}"


def get_truncated_block_log(node, block_count: int):
    output_block_log_path = tt.context.get_current_directory() / "block_log"
    output_block_log_path.unlink(missing_ok=True)
    output_block_log_artifacts_path = (tt.context.get_current_directory() / "block_log.artifacts")
    output_block_log_artifacts_path.unlink(missing_ok=True)
    block_log = node.block_log.truncate(tt.context.get_current_directory(), block_count)
    return block_log
