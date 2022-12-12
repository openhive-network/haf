from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm.exc import MultipleResultsFound

import test_tools as tt

from haf_local_tools import make_fork, wait_for_irreversible_progress, prepare_networks
from haf_local_tools.tables import Operations


START_TEST_BLOCK = 108


def test_undo_operations(prepared_networks_and_database):
    tt.logger.info(f'Start test_undo_operations')

    # GIVEN
    networks, session = prepared_networks_and_database
    node_under_test = networks['Beta'].node('ApiNode0')

    # WHEN
    prepare_networks(networks)
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    wallet = tt.Wallet(attach_to=node_under_test)
    transaction = wallet.api.transfer_to_vesting('initminer', 'null', tt.Asset.Test(1234), broadcast=False)

    tt.logger.info(f'Making fork at block {START_TEST_BLOCK}')
    fork_block = START_TEST_BLOCK
    after_fork_block = make_fork(
        networks,
        fork_chain_trxs=[transaction],
    )

    # THEN
    wait_for_irreversible_progress(node_under_test, after_fork_block)
    for i in range(fork_block, after_fork_block):
        try:
            # there should be exactly one producer_reward_operation
            session.query(Operations).filter(Operations.block_num == i).one()
        
        except MultipleResultsFound:
            tt.logger.error(f'Multiple operations in block {i}.')
            raise
        except NoResultFound:
            tt.logger.error(f'No producer_reward_operation in block {i}.')
            raise
