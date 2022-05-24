import json
from pathlib import Path

import test_tools as tt

from local_tools import make_fork, wait_for_irreversible_progress, run_networks


START_TEST_BLOCK = 108


def test_operations_after_switchng_fork(prepared_networks_and_database):
    tt.logger.info(f'Start test_operations_after_switchng_fork')

    # GIVEN
    networks, session, Base = prepared_networks_and_database
    node_under_test = networks['Beta'].node('ApiNode0')
    transactions = Base.classes.transactions
    operations = Base.classes.operations

    # WHEN
    run_networks(networks)
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    wallet = tt.Wallet(attach_to=node_under_test)
    transaction1 = wallet.api.transfer('initminer', 'null', tt.Asset.Test(1234), 'memo', broadcast=False)
    transaction2 = wallet.api.transfer_to_vesting('initminer', 'null', tt.Asset.Test(1234), broadcast=False)

    tt.logger.info(f'Making fork at block {START_TEST_BLOCK}')
    after_fork_block = make_fork(
        networks,
        main_chain_trxs=[transaction1],
        fork_chain_trxs=[transaction2],
    )

    # THEN
    wait_for_irreversible_progress(node_under_test, after_fork_block)
    trx = session.query(transactions).filter(transactions.block_num > START_TEST_BLOCK).one()

    ops = session.query(operations).filter(operations.block_num == trx.block_num).all()
    types = [json.loads(op.body)['type'] for op in ops]

    assert 'producer_reward_operation' in types
    assert 'transfer_operation' in types
    assert 'transfer_to_vesting_operation' not in types
