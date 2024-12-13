from sqlalchemy.orm import Session
from typing import TYPE_CHECKING, Union

import test_tools as tt

from haf_local_tools.haf_node._haf_node import HafNode, Transaction, TransactionId
from haf_local_tools.tables import BlocksView


def connect_nodes(seed_node: tt.RawNode, peer_node: tt.RawNode) -> None:
    """
    This place have to be removed after solving issue https://gitlab.syncad.com/hive/test-tools/-/issues/10
    """
    peer_node.config.p2p_seed_node = seed_node.p2p_endpoint.as_string()


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
    return session.execute("""
    SELECT 1
    FROM pg_index i
    JOIN pg_class idx ON i.indexrelid = idx.oid
    JOIN pg_class tbl ON i.indrelid = tbl.oid
    JOIN pg_namespace n ON tbl.relnamespace = n.oid
    WHERE n.nspname = :ns
    AND tbl.relname = :table
    AND idx.relname = :index
    """, {'ns':namespace, 'table': table, 'index': indexname}).fetchone()


def assert_index_exists(session, namespace, table, indexname):
    assert does_index_exist(session, namespace, table, indexname)


def assert_index_does_not_exist(session, namespace, table, indexname):
    assert not does_index_exist(session, namespace, table, indexname)


def wait_till_registered_indexes_created(haf_node, context):
    haf_node.session.execute("select hive.wait_till_registered_indexes_created(:ctx)", {'ctx': context})


def register_index_dependency(haf_node, context, stage, create_index_command):
    haf_node.session.execute(
            "SELECT hive.register_index_dependency(:ctx, :stage, :cmd)", {'ctx':  context, 'stage': stage, 'cmd': create_index_command})


def assert_is_transaction_in_database(haf_node: HafNode, transaction:  Union[Transaction, TransactionId]):
    try:
        haf_node.wait_for_transaction_in_database(transaction=transaction, timeout=0)
    except TimeoutError:
        assert False, "Transaction NOT exist in database"
    return True


def get_truncated_block_log(node, block_count: int):
    output_block_log_path = tt.context.get_current_directory() / "block_log"
    output_block_log_path.unlink(missing_ok=True)
    output_block_log_artifacts_path = (tt.context.get_current_directory() / "block_log.artifacts")
    output_block_log_artifacts_path.unlink(missing_ok=True)
    block_log = node.block_log.truncate(tt.context.get_current_directory(), block_count)
    return block_log
