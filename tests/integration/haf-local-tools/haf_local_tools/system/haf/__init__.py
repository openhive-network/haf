from sqlalchemy.orm import Session
from typing import TYPE_CHECKING

import test_tools as tt

from haf_local_tools.haf_node._haf_node import HafNode
from haf_local_tools.tables import BlocksView


def connect_nodes(first_node, second_node) -> None:
    """
    This place have to be removed after solving issue https://gitlab.syncad.com/hive/test-tools/-/issues/10
    """
    from test_tools.__private.user_handles.get_implementation import get_implementation

    second_node.config.p2p_seed_node = get_implementation(first_node).get_p2p_endpoint()


def prepare_network_with_init_node_and_haf_node(init_node_time_offset: str = None):
    init_node = tt.InitNode()
    init_node.run(time_offset=init_node_time_offset)

    haf_node = HafNode(keep_database=True)

    return haf_node, init_node


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
    assert blocks_in_database == limit_block_num


def assert_are_disabled_indexes_of_irreversible_called_correct(
    haf_node: HafNode, expected_disable_indexes_calls: int
) -> bool:
    # verify that disable_indexes_of_irreversible was called as expected
    function_calls = haf_node.query_one(
        "SELECT calls FROM pg_stat_user_functions WHERE funcname = 'disable_indexes_of_irreversible';"
    )
    assert function_calls == expected_disable_indexes_calls


def assert_are_indexes_restored(haf_node: HafNode):
    # verify that indexes are restored
    indexes = haf_node.query_all(
        "SELECT indexname FROM pg_indexes WHERE tablename='blocks'"
    )
    assert len(indexes) > 0
