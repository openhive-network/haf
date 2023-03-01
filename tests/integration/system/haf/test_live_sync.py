import json

import test_tools as tt

from haf_local_tools import get_head_block, get_irreversible_block, wait_for_irreversible_progress, prepare_networks
from haf_local_tools.tables import Blocks, Transactions, Operations


START_TEST_BLOCK = 108


def test_live_sync(prepared_networks_and_database):
    tt.logger.info(f'Start test_live_sync')

    # GIVEN
    networks_builder, session = prepared_networks_and_database
    witness_node = networks_builder.networks[0].node('WitnessNode0')
    node_under_test = networks_builder.networks[1].node('ApiNode0')

    # WHEN
    prepare_networks(networks_builder.networks)
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
    assert sorted(block_nums) == [i for i in range(1, irreversible_block+1)]

    tt.logger.info(f'head_block: {head_block} irreversible_block: {irreversible_block}')

    session.query(Transactions).filter(Transactions.block_num == transaction_block_num).one()

    ops = session.query(Operations).filter(Operations.block_num == transaction_block_num).all()
    types = [json.loads(op.body)['type'] for op in ops]

    assert 'transfer_operation' in types
    assert 'producer_reward_operation' in types
