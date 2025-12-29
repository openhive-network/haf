import pytest
import time

import test_tools as tt
from sqlalchemy.sql import text

from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround
from haf_local_tools.system.haf import (
    connect_nodes,
    assert_are_blocks_sync_with_haf_db,
    assert_are_indexes_restored,
    assert_is_transaction_in_database,
)
from haf_local_tools.system.haf.mirrornet.constants import (
    SKELETON_KEY,
    CHAIN_ID,
    TRANSACTION_IN_1092_BLOCK,
    TRANSACTION_IN_999892_BLOCK,
)
from haf_local_tools import (
    wait_for_block_in_database,
)


def debug_transaction_state(haf_node, expected_trx_hash: str):
    """Debug helper to diagnose transaction indexing issues."""
    session = haf_node.session

    tt.logger.info("=" * 60)
    tt.logger.info("DEBUG: Transaction indexing state")
    tt.logger.info("=" * 60)

    # Check HAF state
    try:
        state = session.execute(text("SELECT * FROM hafd.hive_state")).fetchone()
        tt.logger.info(f"HAF state: {dict(state._mapping) if state else 'None'}")
    except Exception as e:
        tt.logger.error(f"Failed to get HAF state: {e}")

    # Check total transaction count
    try:
        count = session.execute(text("SELECT COUNT(*) FROM hafd.transactions")).scalar()
        tt.logger.info(f"Total transactions in hafd.transactions: {count}")
    except Exception as e:
        tt.logger.error(f"Failed to count transactions: {e}")

    # Check reversible transaction count
    try:
        count = session.execute(text("SELECT COUNT(*) FROM hafd.transactions_reversible")).scalar()
        tt.logger.info(f"Total transactions in hafd.transactions_reversible: {count}")
    except Exception as e:
        tt.logger.error(f"Failed to count reversible transactions: {e}")

    # Check blocks count
    try:
        count = session.execute(text("SELECT COUNT(*) FROM hafd.blocks")).scalar()
        tt.logger.info(f"Total blocks in hafd.blocks: {count}")
    except Exception as e:
        tt.logger.error(f"Failed to count blocks: {e}")

    # Check transactions in block 1092
    try:
        trxs = session.execute(text(
            "SELECT block_num, trx_in_block, encode(trx_hash, 'hex') as trx_hash "
            "FROM hafd.transactions WHERE block_num = 1092"
        )).fetchall()
        tt.logger.info(f"Transactions in block 1092: {len(trxs)}")
        for trx in trxs[:5]:  # Show up to 5
            tt.logger.info(f"  block={trx.block_num}, trx_in_block={trx.trx_in_block}, hash={trx.trx_hash}")
    except Exception as e:
        tt.logger.error(f"Failed to get transactions in block 1092: {e}")

    # Check transactions in block 999892
    try:
        trxs = session.execute(text(
            "SELECT block_num, trx_in_block, encode(trx_hash, 'hex') as trx_hash "
            "FROM hafd.transactions WHERE block_num = 999892"
        )).fetchall()
        tt.logger.info(f"Transactions in block 999892: {len(trxs)}")
        for trx in trxs[:5]:
            tt.logger.info(f"  block={trx.block_num}, trx_in_block={trx.trx_in_block}, hash={trx.trx_hash}")
    except Exception as e:
        tt.logger.error(f"Failed to get transactions in block 999892: {e}")

    # Try to find the expected transaction
    try:
        result = session.execute(text(
            "SELECT block_num, trx_in_block, encode(trx_hash, 'hex') as trx_hash "
            "FROM hive.transactions_view WHERE trx_hash = decode(:hash, 'hex')"
        ), {"hash": expected_trx_hash}).fetchone()
        tt.logger.info(f"Looking for transaction {expected_trx_hash}: {'FOUND' if result else 'NOT FOUND'}")
        if result:
            tt.logger.info(f"  Found at block={result.block_num}, trx_in_block={result.trx_in_block}")
    except Exception as e:
        tt.logger.error(f"Failed to search for transaction: {e}")

    # Show sample of first few transactions
    try:
        trxs = session.execute(text(
            "SELECT block_num, trx_in_block, encode(trx_hash, 'hex') as trx_hash "
            "FROM hafd.transactions ORDER BY block_num LIMIT 10"
        )).fetchall()
        tt.logger.info(f"First 10 transactions in database:")
        for trx in trxs:
            tt.logger.info(f"  block={trx.block_num}, trx_in_block={trx.trx_in_block}, hash={trx.trx_hash}")
    except Exception as e:
        tt.logger.error(f"Failed to get sample transactions: {e}")

    # Check psql_url config
    tt.logger.info(f"HafNode database_url: {haf_node.database_url}")
    tt.logger.info(f"HafNode psql_url config: {haf_node.config.psql_url}")

    tt.logger.info("=" * 60)


@pytest.mark.mirrornet
@pytest.mark.parametrize(
    "psql_index_threshold",
    [6000000, 100000],
    ids=["enabled_indexes", "disabled_indexes_in_p2p_sync"],
)
def test_p2p_sync(mirrornet_witness_node, haf_node, block_log_5m, tmp_path, psql_index_threshold):
    haf_node.config.psql_index_threshold = psql_index_threshold

    block_log_1m = block_log_5m.truncate(tmp_path, 1000000)
    apply_block_log_type_to_monolithic_workaround(mirrornet_witness_node)
    mirrornet_witness_node.run(
        replay_from=block_log_1m,
        time_control=tt.StartTimeControl(start_time="head_block_time"),
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID, "--skeleton-key", SKELETON_KEY],
    )

    head_block_time = mirrornet_witness_node.get_head_block_time()

    connect_nodes(mirrornet_witness_node, haf_node)

    haf_node.run(
        time_control=tt.StartTimeControl(start_time=head_block_time),
        wait_for_live=True,
        timeout=3600,
        arguments=["--chain-id", CHAIN_ID],
    )

    wait_for_block_in_database(haf_node.session, 1000000)

    # Debug: Check transaction indexing state before assertions
    debug_transaction_state(haf_node, TRANSACTION_IN_1092_BLOCK)

    assert_is_transaction_in_database(haf_node, TRANSACTION_IN_1092_BLOCK)
    assert_is_transaction_in_database(haf_node, TRANSACTION_IN_999892_BLOCK)
    assert_are_indexes_restored(haf_node)

    haf_node.close()  # wait for node to flush wal and close
