from pathlib import Path

from test_tools import logger, Wallet, Asset
from local_tools import get_irreversible_block, get_head_block, run_networks, make_fork, wait_for_irreversible_progress, run_networks
from threading import Thread


START_TEST_BLOCK = 108



def test_revert_trx_order(world_with_witnesses_and_database):
    logger.info(f'Start test_revert_trx_order')
    # GIVEN
    world, session, Base = world_with_witnesses_and_database
    alpha_witness_node = world.network('Alpha').node('WitnessNode0')
    beta_witness_node = world.network('Beta').node('WitnessNode0')
    node_under_test = world.network('Beta').node('NodeUnderTest')

    # WHEN
    run_networks(world, Path().resolve())
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)

    alpha_wallet = Wallet(attach_to=alpha_witness_node)
    beta_wallet = Wallet(attach_to=beta_witness_node)

    head_block = get_head_block(node_under_test)
    irreversible = get_irreversible_block(node_under_test)

    node_under_test.wait_for_block_with_number(START_TEST_BLOCK+3)

    # THEN
    logger.info("Sending trx")



    try:
        alpha_wallet.api.transfer_nonblocking('initminer', 'null', Asset.Test(1000), 'dummy transfer operation2', )
    except: pass
    try:
        alpha_wallet.api.transfer_nonblocking('initminer', 'null', Asset.Test(1000), 'dummy transfer operation1', )
    except: pass

    try:
        beta_wallet.api.transfer_nonblocking('initminer', 'null', Asset.Test(1000), 'dummy transfer operation1')
    except: pass
    try:
        beta_wallet.api.transfer_nonblocking('initminer', 'null', Asset.Test(1000), 'dummy transfer operation2')
    except: pass

    head_block = get_head_block(node_under_test)
    logger.info(f"transfers done at block {head_block}")
    while True:
        pass
