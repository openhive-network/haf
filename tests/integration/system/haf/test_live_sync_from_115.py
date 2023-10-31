import json

from sqlalchemy import cast
from sqlalchemy.dialects.postgresql import JSONB

import test_tools as tt

from haf_local_tools import get_head_block, get_irreversible_block, wait_for_irreversible_progress
from haf_local_tools.tables import Blocks, BlocksView, Transactions, Operations


START_TEST_BLOCK =  115


def test_live_sync_from_115(prepared_networks_and_database_12_8_from_115):
    tt.logger.info(f'Start test_live_sync_from_115')

    # GIVEN
    networks_builder, session = prepared_networks_and_database_12_8_from_115
    witness_node = networks_builder.networks[0].node('WitnessNode0')
    node_under_test = networks_builder.networks[1].node('ApiNode0')

    # WHEN
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    wallet = tt.Wallet(attach_to=witness_node)
    wallet.api.transfer('initminer', 'initminer', tt.Asset.Test(1000), 'dummy transfer operation')
    transaction_block_num = START_TEST_BLOCK + 1

    # THEN
    wait_for_irreversible_progress(node_under_test, transaction_block_num)
    head_block = get_head_block(node_under_test)
    irreversible_block = get_irreversible_block(node_under_test)

    blks = session.query(Blocks).order_by(Blocks.num).all()
    block_nums = [block.num for block in blks]
    assert sorted(block_nums)[:2] == [i for i in [0, 115]]

    tt.logger.info(f'head_block: {head_block} irreversible_block: {irreversible_block}')

    session.query(Transactions).filter(Transactions.block_num == transaction_block_num).one()

    ops = session.query(Operations).add_columns(cast(Operations.body_binary, JSONB).label('body'), Operations.block_num).filter(Operations.block_num == transaction_block_num).all()
    types = [op.body['type'] for op in ops]

    assert 'transfer_operation' in types
    assert 'producer_reward_operation' in types
