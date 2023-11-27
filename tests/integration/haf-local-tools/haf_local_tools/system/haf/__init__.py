from sqlalchemy.orm import Session
from typing import TYPE_CHECKING, Union

import test_tools as tt

from haf_local_tools.haf_node._haf_node import HafNode, Transaction, TransactionId
from haf_local_tools.tables import BlocksView


def connect_nodes(first_node: tt.RawNode, second_node: tt.RawNode) -> None:
    """
    This place have to be removed after solving issue https://gitlab.syncad.com/hive/test-tools/-/issues/10
    """
    second_node.config.p2p_seed_node = first_node.p2p_endpoint.as_string()


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
    # verify that indexes are restored
    are_indexes_dropped = haf_node.query_one("SELECT hive.are_indexes_dropped()")
    assert are_indexes_dropped == False


def assert_is_transaction_in_database(haf_node: HafNode, transaction:  Union[Transaction, TransactionId]):
    try:
        haf_node.wait_for_transaction_in_database(transaction=transaction, timeout=0)
    except TimeoutError:
        assert False, "Transaction NOT exist in database"
    return True
