import test_tools as tt

from haf_local_tools import make_fork, wait_for_irreversible_progress, prepare_networks
from haf_local_tools.tables import Transactions

START_TEST_BLOCK = 108


def test_undo_transactions(prepared_networks_and_database):
    tt.logger.info(f'Start test_undo_transactions')

    # GIVEN
    networks_builder, session = prepared_networks_and_database
    node_under_test = networks_builder.networks[1].node('ApiNode0')

    # WHEN
    prepare_networks(networks_builder.networks)
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    wallet = tt.Wallet(attach_to=node_under_test)
    transaction = wallet.api.transfer_to_vesting('initminer', 'null', tt.Asset.Test(1234), broadcast=False)

    tt.logger.info(f'Making fork at block {START_TEST_BLOCK}')
    after_fork_block = make_fork(
        networks_builder.networks,
        fork_chain_trxs=[transaction],
    )

    # THEN
    wait_for_irreversible_progress(node_under_test, after_fork_block)
    trxs = session.query(Transactions).filter(Transactions.block_num > START_TEST_BLOCK).all()

    assert trxs == []
