from datetime import timedelta

import test_tools as tt
from test_tools.__private.node import Node
from test_tools.__private.process.node_config import NodeConfig
from test_tools.__private.user_handles.get_implementation import get_implementation

from haf_local_tools import get_irreversible_block
from haf_local_tools.haf_node import HafNode
from haf_local_tools.system.haf import (
    assert_are_blocks_sync_with_haf_db,
    connect_nodes,
    create_and_run_init_node_with_retry,
    prepare_and_send_transactions,
    get_truncated_block_log,
)


def test_replay_and_p2p_sync_in_lite_mode(haf_node: HafNode, lite_mode_configs: list[NodeConfig]) -> None:
    """Blocks that were still reversible when a lite-mode node switched from P2P sync to LIVE reach the database
    once they become irreversible, so no hole is left between the synced range and the live one."""
    init_node = create_and_run_init_node_with_retry()
    lite_mode_configs.append(haf_node.config)

    transaction_0, transaction_1 = prepare_and_send_transactions(init_node)

    node_impl = get_implementation(init_node, Node)
    with node_impl.update_settings() as settings:
        settings.close_timeout = timedelta(seconds=30)
    init_node.close()
    block_log = get_truncated_block_log(init_node, transaction_0["block_num"] + 1)

    init_node.run()
    connect_nodes(init_node, haf_node)

    haf_node.run(replay_from=block_log, wait_for_live=True)

    head_block_num_when_live_start = haf_node.get_last_block_number()
    tt.logger.info(
        f"LIVE entered at head {head_block_num_when_live_start}, irreversible {get_irreversible_block(haf_node)}"
    )
    assert head_block_num_when_live_start > transaction_1["block_num"]
    assert haf_node.query_one("SELECT hive.is_lite_mode()") is True

    # Lite mode writes a block only once it is irreversible.
    tt.Time.wait_for(
        lambda: haf_node.query_one("SELECT COALESCE(MAX(num), 0) FROM hive.blocks_view")
        >= head_block_num_when_live_start,
        timeout=timedelta(minutes=3),
        timeout_error_message=f"Block {head_block_num_when_live_start} never reached the database",
    )

    haf_node.wait_for_transaction_in_database(transaction_0, timeout=timedelta(seconds=30))
    haf_node.wait_for_transaction_in_database(transaction_1, timeout=timedelta(seconds=30))

    assert_are_blocks_sync_with_haf_db(haf_node, head_block_num_when_live_start)
