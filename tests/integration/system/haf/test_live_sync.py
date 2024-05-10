from sqlalchemy import cast
from sqlalchemy.dialects.postgresql import JSONB

import test_tools as tt

from haf_local_tools import (
    get_head_block,
    get_irreversible_block,
    wait_for_irreversible_progress,
    wait_for_irreversible_in_database,
    get_first_block_with_transaction)
from haf_local_tools.tables import Blocks, BlocksView, Transactions, OperationsIrreversibleView


START_TEST_BLOCK =  115


def display_blocks_information(node):
    h_b = get_head_block(node)
    i_b = get_irreversible_block(node)
    tt.logger.info(f'head_block: {h_b} irreversible_block: {i_b}')
    return h_b, i_b


def test_live_sync(prepared_networks_and_database_12_8):
    tt.logger.info(f'Start test_live_sync')

    # GIVEN
    networks_builder, session = prepared_networks_and_database_12_8
    witness_node = networks_builder.networks[0].node('WitnessNode0')
    node_under_test = networks_builder.networks[1].node('ApiNode0')

    # WHEN
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    wallet = tt.Wallet(attach_to=witness_node)

    #Find a current block, shortly after a wallet attaching
    #Attaching a wallet can last even a few seconds, so searching a transaction should be done from `transaction_block_num` block after attaching.
    transaction_block_num, _ = display_blocks_information(node_under_test)

    wallet.api.transfer('initminer', 'initminer', tt.Asset.Test(1000), 'dummy transfer operation')

    # THEN
    # nr_blocks - number of blocks in which potentially transaction was inserted
    # value was determined through observation during CI testing
    nr_blocks = 2
    expected_dumped_irreversible_block_num = transaction_block_num + nr_blocks
    wait_for_irreversible_in_database(session, expected_dumped_irreversible_block_num)
    trx_found = None

    #Sometimes pushing a transaction into a node is delayed, especially when the node is not ready at the moment (see: `Unable to acquire database lock`)
    #As a result the transaction (here with `transfer` operation) should be found in <transaction_block_num; transaction_block_num + nr_blocks) range of blocks
    #Solution:
    #Try to find the transaction in 'nr_blocks' blocks

    transaction_block_num = get_first_block_with_transaction(
        session
        , range(transaction_block_num, transaction_block_num + nr_blocks))

    blks = session.query(Blocks).filter(Blocks.num <= expected_dumped_irreversible_block_num).order_by(Blocks.num).all()
    block_nums = [block.num for block in blks]

    assert sorted(block_nums) == [i for i in range(1, expected_dumped_irreversible_block_num+1)]

    ops = (session.query(OperationsIrreversibleView)
           .add_columns(cast(OperationsIrreversibleView.body_binary, JSONB).label('body'), OperationsIrreversibleView.block_num)
           .filter(OperationsIrreversibleView.block_num == transaction_block_num).all())
    types = [op.body['type'] for op in ops]

    assert 'transfer_operation' in types
    assert 'producer_reward_operation' in types
