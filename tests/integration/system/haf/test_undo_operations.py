from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm.exc import MultipleResultsFound
from sqlalchemy import text

import test_tools as tt

from haf_local_tools import make_fork, wait_for_irreversible_progress
from haf_local_tools.tables import OperationsIrreversibleView


START_TEST_BLOCK = 108


def wait_for_haf_irreversible(session, block_num: int, timeout: float = 60.0, poll_time: float = 0.5):
    """Wait for HAF to process blocks up to block_num (checks hive.app_get_irreversible_block())."""
    def haf_has_block():
        result = session.execute(text("SELECT hive.app_get_irreversible_block()")).scalar()
        return result is not None and result >= block_num

    tt.Time.wait_for(
        haf_has_block,
        timeout=timeout,
        timeout_error_message=f"HAF did not reach irreversible block {block_num}",
        poll_time=poll_time,
    )


def test_undo_operations(prepared_networks_and_database_12_8):
    tt.logger.info(f'Start test_undo_operations')

    # GIVEN
    networks_builder, session = prepared_networks_and_database_12_8
    node_under_test = networks_builder.networks[1].node('ApiNode0')

    # WHEN
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    wallet = tt.Wallet(attach_to=node_under_test)
    transaction = wallet.api.transfer_to_vesting('initminer', 'null', tt.Asset.Test(1234), broadcast=False)

    tt.logger.info(f'Making fork at block {START_TEST_BLOCK}')
    fork_block = START_TEST_BLOCK
    after_fork_block = make_fork(
        networks_builder.networks,
        fork_chain_trxs=[transaction],
    )

    # THEN
    # Wait for hived to report blocks as irreversible
    wait_for_irreversible_progress(node_under_test, after_fork_block)
    # Wait for HAF database to actually process those blocks
    wait_for_haf_irreversible(session, after_fork_block - 1)

    for i in range(fork_block, after_fork_block):
        try:
            # there should be exactly one producer_reward_operation
            session.query(OperationsIrreversibleView).filter(OperationsIrreversibleView.block_num == i).one()

        except MultipleResultsFound:
            tt.logger.error(f'Multiple operations in block {i}.')
            raise
        except NoResultFound:
            tt.logger.error(f'No producer_reward_operation in block {i}.')
            raise
