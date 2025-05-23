from pathlib import Path
from typing import Iterable
import pytest
import loguru
from functools import partial
from concurrent.futures import ThreadPoolExecutor

import test_tools as tt

import shared_tools.complex_networks_helper_functions as sh
from haf_local_tools import haf_app

START_TEST_BLOCK    = 108
memo_cnt            = 0

break_cnt           = 0
break_limit         = 250

def generate_break(node: tt.ApiNode, identifier: int):
    global break_cnt
    global break_limit

    while break_cnt < break_limit:
        node.wait_number_of_blocks(1)
        break_cnt += 1
    return f'[break {identifier}] Breaking activated...'

def haf_app_processor(before_kill_time_min: int, before_kill_time_max: int, identifier: int):
    global break_cnt
    global break_limit

    while break_cnt < break_limit:
        _app = haf_app(identifier, before_kill_time_min, before_kill_time_max)
        tt.logger.info( f"app runs: {identifier}")
        _app.run()
    return f'[break {identifier}] Creating apps finished...'

def fork_activator(networks: Iterable[tt.Network], logs: Iterable[sh.NodeLog], majority_api_node: tt.ApiNode, _m: Iterable[sh.info], _M: Iterable[sh.info], identifier: int):
    _cnt = 1

    global break_cnt
    global break_limit

    while break_cnt < break_limit:
        tt.logger.info(f'Disconnect sub networks: {_cnt}...')
        sh.disconnect_sub_networks(networks)

        sh.wait(5, logs, majority_api_node)

        _last_lib_M = sh.get_last_irreversible_block_num(_M)
        tt.logger.info(f'last Lib: {_last_lib_M}...')

        tt.logger.info(f'Reconnect sub networks: {_cnt}...')
        sh.connect_sub_networks(networks)

        sh.wait_for_final_block(majority_api_node, logs, [_m, _M], True, partial(sh.lib_custom_condition, _M, _last_lib_M), False)
        tt.logger.info(f'Sub networks reconnected: {_cnt}...')

        _cnt += 1
    return f'[break {identifier}] Creating forks finished...'

def trx_creator(wallet: tt.Wallet, identifier: int, start_memo: int, last_memo: int):
    for memo in range(start_memo, last_memo):
        wallet.api.transfer_nonblocking('initminer', 'null', tt.Asset.Test(1), str(memo))
    return f'[break {identifier}] Creating transactions finished...'

#Some information in: https://gitlab.syncad.com/hive/haf/-/issues/118
def test_many_forks_many_ops_db(prepared_networks_and_database_17_3):
    loguru.logger.enable("helpy")
    global break_cnt
    global break_limit

    tt.logger.info(f'Start test_many_forks_many_ops_db')

    networks_builder, session = prepared_networks_and_database_17_3

    haf_app.setup(session, Path(__file__).parent.absolute() / ".." / ".." / ".." / ".." / "src" / "hive_fork_manager" / "doc" / "applications")

    majority_api_node = networks_builder.networks[0].node('ApiNode0')
    minority_api_node = networks_builder.networks[1].node('ApiNode1')

    minority_api_node.wait_for_block_with_number(START_TEST_BLOCK)

    logs = []

    majority_wallet = tt.Wallet(attach_to = majority_api_node)
    minority_wallet = tt.Wallet(attach_to = minority_api_node)
    logs.append(sh.NodeLog("M", majority_wallet))
    logs.append(sh.NodeLog("m", minority_wallet))

    _M = logs[0].collector
    _m = logs[1].collector

    blocks_before_disconnect = 5

    tt.logger.info(f'Before disconnecting...')
    cnt = 0
    while not (cnt > blocks_before_disconnect and sh.get_last_irreversible_block_num(_M) == sh.get_last_irreversible_block_num(_m)):
        sh.wait(1, logs, majority_api_node)
        cnt += 1

    break_cnt = sh.get_last_irreversible_block_num(_M)
    tt.logger.info(f'initial break_cnt: {break_cnt}')

    _futures                = []
    _fork_threads           = 1
    _push_threads           = 2
    _app_threads            = 1
    _generate_break_threads = 1
    with ThreadPoolExecutor(max_workers = _fork_threads + _push_threads + _app_threads + _generate_break_threads ) as executor:
        _futures.append(executor.submit(fork_activator, networks_builder.networks, logs, majority_api_node, _m, _M, 0))

        step = break_limit // _push_threads
        for i in range(_push_threads):
            start_memo = step * i
            last_memo = start_memo + step
            if i % 2 == 0:
                _futures.append(executor.submit(trx_creator, majority_wallet, i, start_memo, last_memo))
            else:
                _futures.append(executor.submit(trx_creator, minority_wallet, i, start_memo, last_memo))

        for i in range(_app_threads):
            _futures.append(executor.submit(haf_app_processor, 5, 30, i ))

        _futures.append(executor.submit(generate_break, majority_api_node, 0 ))

    tt.logger.info("results:")
    for future in _futures:
        tt.logger.info(f'{future.result()}') # Possible random fail: https://gitlab.syncad.com/hive/haf/-/issues/251
