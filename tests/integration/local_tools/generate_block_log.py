#!/usr/bin/env python3
import argparse
import os
from pathlib import Path

import test_tools as tt

from test_tools.__private.block_log import BlockLog

from witnesses import alpha_witness_names, beta_witness_names


class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


def prepare_block_log(length):
    tt.cleanup_policy.set_default(tt.constants.CleanupPolicy.DO_NOT_REMOVE_FILES)

    all_witness_names = alpha_witness_names + beta_witness_names

    # Create first network
    alpha_net = tt.Network()
    beta_net = tt.Network()
    init_node = tt.InitNode(network=alpha_net)

    for i in range(4):
        first = int(i * len(alpha_witness_names) / 4)
        last = int((i+1) * len(alpha_witness_names) / 4)
        tt.WitnessNode(network=alpha_net, witnesses=alpha_witness_names[first:last])
    api_node = tt.ApiNode(network=alpha_net)

    for i in range(4):
        first = int(i * len(beta_witness_names) / 4)
        last = int((i+1) * len(beta_witness_names) / 4)
        tt.WitnessNode(network=beta_net, witnesses=beta_witness_names[first:last])
        
    # Run
    alpha_net.connect_with(beta_net)

    tt.logger.info('Running networks, waiting for live...')
    alpha_net.run()
    beta_net.run()

    tt.logger.info('Attaching wallets...')
    wallet = tt.Wallet(attach_to=api_node)
    # We are waiting here for block 43, because witness participation is counting
    # by dividing total produced blocks in last 128 slots by 128. When we were waiting
    # too short, for example 42 blocks, then participation equals 42 / 128 = 32.81%.
    # It is not enough, because 33% is required. 43 blocks guarantee, that this
    # requirement is always fulfilled (43 / 128 = 33.59%, which is greater than 33%).
    tt.logger.info('Wait for block 43 (to fulfill required 33% of witness participation)')
    init_node.wait_for_block_with_number(43)

    # Prepare witnesses on blockchain
    with wallet.in_single_transaction():
        for name in all_witness_names:
            wallet.api.create_account('initminer', name, '')
    with wallet.in_single_transaction():
        for name in all_witness_names:
            wallet.api.transfer_to_vesting('initminer', name, tt.Asset.Test(1000))
    with wallet.in_single_transaction():
        for name in all_witness_names:
            wallet.api.update_witness(
                name, 'https://' + name,
                tt.Account(name).public_key,
                {'account_creation_fee': tt.Asset.Test(3), 'maximum_block_size': 65536, 'sbd_interest_rate': 0}
            )

    tt.logger.info('Wait 21 blocks to schedule newly created witnesses')
    init_node.wait_number_of_blocks(21)

    tt.logger.info('Witness state after voting')
    response = api_node.api.database.list_witnesses(start=0, limit=100, order='by_name')
    active_witnesses = response['witnesses']
    active_witnesses_names = [witness['owner'] for witness in active_witnesses]
    tt.logger.info(active_witnesses_names)
    assert len(active_witnesses_names) == 21

    # Reason of this wait is to enable moving forward of irreversible block
    tt.logger.info('Wait 21 blocks (when every witness sign at least one block)')
    init_node.wait_number_of_blocks(21)
    tt.logger.info('Wait 21 blocks for future slate to become active slate')
    init_node.wait_number_of_blocks(21)

    # Network should be set up at this time, with 21 active witnesses, enough participation rate
    # and irreversible block number lagging behind around 15-20 blocks head block number
    result = wallet.api.info()
    irreversible = result['last_irreversible_block_num']
    head = result['head_block_num']
    tt.logger.info(f'Network prepared, irreversible block: {irreversible}, head block: {head}')

    # with fast confirm, irreversible will usually be = head
    # assert irreversible + 10 < head

    while irreversible < length:
        init_node.wait_number_of_blocks(1)
        result = wallet.api.info()
        irreversible = result['last_irreversible_block_num']
        tt.logger.info(
            f'Generating block_log of length: {length}, '
            f'current irreversible: {result["last_irreversible_block_num"]}, '
            f'current head block: {result["head_block_num"]}'
        )

    if os.path.exists('block_log'):
        os.remove('block_log')

    timestamp = init_node.api.block.get_block(block_num=length)['block']['timestamp']

    input_block_log_path    = init_node.get_block_log().get_path().parent.absolute()
    output_block_log_path   = Path('block_log').parent.absolute()
    init_node.close()

    BlockLog.truncate(input_block_log_path, output_block_log_path, length)

    return timestamp


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--length', type=int, default=105, help='Desired blocklog length')
    args = parser.parse_args()

    timestamp = prepare_block_log(args.length)
    tt.logger.info(f'{bcolors.OKGREEN}timestamp: {timestamp}{bcolors.ENDC}')

    with open('timestamp', 'w') as f:
        f.write(f'{timestamp}')
