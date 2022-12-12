import json
from pathlib import Path
import unittest

import test_tools as tt

from local_tools import get_irreversible_block, wait_for_irreversible_progress, run_networks
from tables import Blocks, Transactions, Operations


START_TEST_BLOCK = 108


def test_live_sync(prepared_networks_and_database):
    tt.logger.info(f'Start test_live_sync')

    # GIVEN
    networks, session = prepared_networks_and_database
    witness_node = networks['Alpha'].node('WitnessNode0')
    node_under_test = networks['Beta'].node('ApiNode0')

    # WHEN
    run_networks(networks)
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    wallet = tt.Wallet(attach_to=witness_node)
    wallet.api.transfer('initminer', 'initminer', tt.Asset.Test(1000), 'dummy transfer operation')
    transaction_block_num = START_TEST_BLOCK + 1

    # THEN
    wait_for_irreversible_progress(node_under_test, transaction_block_num)
    irreversible_block = get_irreversible_block(node_under_test)

    blks = session.query(Blocks).order_by(Blocks.num).all()
    block_nums = [block.num for block in blks]
    case = unittest.TestCase()
    case.assertCountEqual(block_nums, range(1, irreversible_block+1))

    session.query(Transactions).filter(Transactions.block_num == transaction_block_num).one()

    ops = session.query(Operations).filter(Operations.block_num == transaction_block_num).all()
    types = [json.loads(op.body)['type'] for op in ops]

    assert 'transfer_operation' in types
    assert 'producer_reward_operation' in types
