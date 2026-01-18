import time

from sqlalchemy import cast
from sqlalchemy.dialects.postgresql import JSONB
import os

import test_tools as tt

from haf_local_tools import (
    get_head_block,
    get_irreversible_block,
    wait_for_irreversible_progress,
    wait_for_irreversible_in_database,
    get_first_block_with_transaction
)
from haf_local_tools.haf_node.monolithic_workaround import apply_block_log_type_to_monolithic_workaround
from haf_local_tools.system.haf import (connect_nodes, assert_index_exists, register_index_dependency)
from haf_local_tools.tables import Blocks, BlocksView, Transactions, OperationsIrreversibleView, OperationsView
from haf_local_tools.haf_node import HafNode
from haf_local_tools import (
    wait_for_block_in_database,
)

START_TEST_BLOCK =  115


def display_blocks_information(node):
    h_b = get_head_block(node)
    i_b = get_irreversible_block(node)
    tt.logger.info(f'head_block: {h_b} irreversible_block: {i_b}')
    return h_b, i_b


def test_live_sync_apply_block_fail(haf_node):
    tt.logger.info(f'Start test_live_sync_error')

    # GIVEN
    # generate blocks with debug plugin to be before witness plugin
    # a transaction is broadcasted which weill land to block 27 (also generated with debug plugin)
    # block 27 will be discarded because of exception in debug plugin
    haf_node.config.witness.append("initminer")
    haf_node.config.private_key.append(tt.PrivateKey("initminer"))

    haf_node.run(alternate_chain_specs=tt.AlternateChainSpecs(
        genesis_time=int(tt.Time.now(serialize=False).timestamp()),
        hardfork_schedule=[tt.HardforkSchedule(hardfork=28, block_num=1)],
    ))

    # move before witness plugin
    haf_node.api.debug_node.debug_generate_blocks(
        debug_key=tt.Account("initminer").private_key,
        count=5, # blocks 2,3,4,5,6
        skip=0,
        miss_blocks=0,
        edit_if_needed=True,
    )

    haf_node.api.debug_node.debug_throw_exception(throw_exception=True)

    wallet = tt.Wallet(attach_to=haf_node)
    wallet.api.import_key(tt.Account("initminer").private_key)
    # haf_node.wait_number_of_blocks(18)
    tx = wallet.api.transfer("initminer", "initminer", tt.Asset.Test(1), "memo1", broadcast=False)
    #tx = wallet.api.claim_account_creation("initminer", tt.Asset.Test(0), broadcast=True)
    tt.logger.info(f'Transaction broadcasted: {tx}')

    # generate block 7 which will fail to be applied
    try:
        haf_node.api.debug_node.debug_generate_blocks(
            debug_key=tt.Account("initminer").private_key,
            count=1, # block 7
            skip=0,
            miss_blocks=0,
            edit_if_needed=True,
        )
    except Exception:
        pass

    haf_node.api.debug_node.debug_throw_exception(throw_exception=False)

    # Check for fork record BEFORE generating new blocks - the fork should already be recorded
    # Wait for block 6 to be processed first (the last successful block before the failed one)
    wait_for_block_in_database(haf_node.session, 6, timeout=10)

    # Wait for the fork record - check immediately after the failed block, not after recovery
    # The fork at block 6 should be recorded as soon as block 7 fails
    sql_check = "SELECT exists(SELECT 1 FROM hafd.fork WHERE block_num = 6);"
    sql_debug = "SELECT * FROM hafd.fork ORDER BY block_num;"
    fork_detected = False
    for i in range(60):  # Try up to 60 times with 0.5s delay (30s total for slow CI)
        if haf_node.query_one(sql_check):
            fork_detected = True
            tt.logger.info(f"Fork at block 6 detected after {(i+1)*0.5}s")
            break
        time.sleep(0.5)

    if not fork_detected:
        # Diagnostic output on failure
        fork_records = haf_node.query_all(sql_debug)
        tt.logger.error(f"Fork table contents: {fork_records}")
        head, irr = display_blocks_information(haf_node)
        tt.logger.error(f"Head block: {head}, Irreversible: {irr}")

    assert fork_detected, "Fork at block 6 was not detected in the database within 30s"

    # Now continue with generating new blocks after fork is confirmed
    haf_node.api.debug_node.debug_generate_blocks(
        debug_key=tt.Account("initminer").private_key,
        count=4, # blocks 7,8,9,10
        skip=0,
        miss_blocks=0,
        edit_if_needed=True,
    )

    wait_for_block_in_database(haf_node.session, 10, timeout=10)

