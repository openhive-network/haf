import time

import pytest
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


@pytest.mark.parametrize("witness_block_before_failure", [False, True], ids=["no_extra_block", "extra_witness_block"])
def test_live_sync_apply_block_fail(haf_node: HafNode, witness_block_before_failure: bool) -> None:
    tt.logger.info(f'Start test_live_sync_error')

    # GIVEN
    # generate blocks with debug plugin to be before witness plugin
    # a transaction is broadcasted which will land in the debug-generated block that fails
    # that block will be discarded because of exception in debug plugin
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

    if witness_block_before_failure:
        # reproduce a loaded runner, where the witness plugin produces a block of its own before the failing one
        haf_node.wait_number_of_blocks(1)

    haf_node.api.debug_node.debug_throw_exception(throw_exception=True)

    wallet = tt.Wallet(attach_to=haf_node)
    wallet.api.import_key(tt.Account("initminer").private_key)
    tx = wallet.api.transfer("initminer", "initminer", tt.Asset.Test(1), "memo1", broadcast=False)
    tt.logger.info(f'Transaction broadcasted: {tx}')

    # While the exception flag is set every block fails to apply, including any the witness plugin produces,
    # so the head block cannot move until the flag is cleared: the fork is expected at this block.
    last_applied_block = get_head_block(haf_node)
    tt.logger.info(f'Head block before the failing block: {last_applied_block}')

    # generate the block which will fail to be applied
    try:
        haf_node.api.debug_node.debug_generate_blocks(
            debug_key=tt.Account("initminer").private_key,
            count=1, # block last_applied_block + 1
            skip=0,
            miss_blocks=0,
            edit_if_needed=True,
        )
    except Exception:
        pass

    assert get_head_block(haf_node) == last_applied_block, "The failing block was applied"

    haf_node.api.debug_node.debug_throw_exception(throw_exception=False)

    # Check for fork record BEFORE generating new blocks - the fork should already be recorded
    # Wait for the last successful block before the failed one to be processed first
    wait_for_block_in_database(haf_node.session, last_applied_block, timeout=10)

    # Wait for the fork record - check immediately after the failed block, not after recovery
    # The fork at the last applied block should be recorded as soon as the next block fails
    sql_check = f"SELECT exists(SELECT 1 FROM hafd.fork WHERE block_num = {last_applied_block});"
    sql_debug = "SELECT * FROM hafd.fork ORDER BY block_num;"
    fork_detected = False
    for i in range(60):  # Try up to 60 times with 0.5s delay (30s total for slow CI)
        if haf_node.query_one(sql_check):
            fork_detected = True
            tt.logger.info(f"Fork at block {last_applied_block} detected after {(i+1)*0.5}s")
            break
        time.sleep(0.5)

    if not fork_detected:
        # Diagnostic output on failure
        fork_records = haf_node.query_all(sql_debug)
        tt.logger.error(f"Fork table contents: {fork_records}")
        head, irr = display_blocks_information(haf_node)
        tt.logger.error(f"Head block: {head}, Irreversible: {irr}")

    assert fork_detected, f"Fork at block {last_applied_block} was not detected in the database within 30s"

    # Now continue with generating new blocks after fork is confirmed
    haf_node.api.debug_node.debug_generate_blocks(
        debug_key=tt.Account("initminer").private_key,
        count=4,
        skip=0,
        miss_blocks=0,
        edit_if_needed=True,
    )

    wait_for_block_in_database(haf_node.session, last_applied_block + 4, timeout=10)
