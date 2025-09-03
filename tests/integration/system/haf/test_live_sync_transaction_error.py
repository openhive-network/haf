import time
from logging import raiseExceptions

from sqlalchemy import cast
from sqlalchemy.dialects.postgresql import JSONB
import os
import pytest
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


def test_live_sync_transaction_error(haf_node):
    tt.logger.info(f'Start test_live_sync_error')

    # GIVEN
    # generate blocks with debug plugin to be before witness plugin
    # a transaction is broadcasted which will land to block 7 (also generated with debug plugin)
    # block 7 will be discarded because of exception in debug plugin
    haf_node.config.witness.append("initminer")
    haf_node.config.private_key.append(tt.PrivateKey("initminer"))
    #haf_node.config.plugin.append("queen")
    #haf_node.config.queen_tx_count = 2

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

    #haf_node.api.debug_node.debug_throw_exception(throw_exception=True)

    wallet = tt.Wallet(attach_to=haf_node)
    wallet.api.import_key(tt.Account("initminer").private_key)
    #haf_node.wait_number_of_blocks(18)

    wallet.api.set_transaction_expiration(3)
    tx_to_pass = wallet.api.transfer("initminer", "initminer", tt.Asset.Test(1), "memo1", broadcast=False)
    tx_to_fail = wallet.api.transfer("initminer", "initminer", tt.Asset.Test(2), "memo2", broadcast=False)

    # WHEN
    # Set a transaction  to fail
    haf_node.api.debug_node.debug_fail_transaction(tx_id=tx_to_fail.transaction_id)


    # THEN
    haf_node.api.network_broadcast.broadcast_transaction(trx=tx_to_pass)
    haf_node.api.network_broadcast.broadcast_transaction(trx=tx_to_fail)

    # when block 7 will be produced than no problem shall occur with its dump to the db
    haf_node.wait_number_of_blocks(7)

    # no transaction should be added because blocks with them failed
    sql = "SELECT exists(SELECT 1 FROM hafd.transactions  WHERE block_num > 6) = FALSE;"
    assert haf_node.query_one(sql)



