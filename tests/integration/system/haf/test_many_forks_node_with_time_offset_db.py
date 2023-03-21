from pathlib import Path
import pytest

from concurrent.futures import ThreadPoolExecutor

import test_tools as tt

import shared_tools.complex_networks_helper_functions as sh
from haf_local_tools import haf_app

memo_cnt            = 0

break_cnt           = 0
break_limit         = 250

def generate_break(wallet, node, identifier):
    global break_cnt
    global break_limit

    while break_cnt < break_limit:
        sh.info("m4", wallet)
        node.wait_number_of_blocks(1)
        break_cnt += 1
    return f'[break {identifier}] Breaking activated...'

def haf_app_processor(before_kill_time_min, before_kill_time_max, identifier):
    global break_cnt
    global break_limit

    while break_cnt < break_limit:
        _app = haf_app(identifier, before_kill_time_min, before_kill_time_max)
        tt.logger.info( f"app runs: {identifier}")
        _app.run()
    return f'[break {identifier}] Creating apps finished...'

def trx_creator(wallet, identifier):
    global memo_cnt

    global break_cnt
    global break_limit

    while break_cnt < break_limit:
        wallet.api.transfer_nonblocking('initminer', 'null', tt.Asset.Test(1), str(memo_cnt))
        memo_cnt += 1
    return f'[break {identifier}] Creating transactions finished...'

#When the issue 118 will be fixed, change `break_limit` temporarily to a value that will be related to a few hours in order to evaluate if everything works
@pytest.mark.skip(reason='https://gitlab.syncad.com/hive/haf/-/issues/118')
def test_many_forks_node_with_time_offset_db(prepared_networks_and_database_4_4_4_4_4):
    global break_cnt
    global break_limit

    tt.logger.info(f'Start test_many_forks_node_with_time_offset_db')

    networks_builder, session = prepared_networks_and_database_4_4_4_4_4

    haf_app.setup(session, Path(__file__).parent.absolute() / ".." / ".." / ".." / ".." / "src" / "hive_fork_manager" / "doc" / "applications")

    node_under_test = networks_builder.networks[1].node('ApiNode0')
    beta_wallet = tt.Wallet(attach_to = node_under_test)

    _, break_cnt = sh.info('m4', beta_wallet)
    tt.logger.info(f'initial break_cnt: {break_cnt}')

    _futures                = []
    _push_threads           = 2
    _app_threads            = 8
    _generate_break_threads = 1
    with ThreadPoolExecutor(max_workers = _push_threads + _app_threads + _generate_break_threads) as executor:
        for i in range(_push_threads):
            _futures.append(executor.submit(trx_creator, beta_wallet, i))

        for i in range(_app_threads):
            _futures.append(executor.submit(haf_app_processor, 1, 5, i))

        _futures.append(executor.submit(generate_break, beta_wallet, node_under_test, 0))

    tt.logger.info("results:")
    for future in _futures:
        tt.logger.info(f'{future.result()}')

