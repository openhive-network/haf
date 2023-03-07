from pathlib import Path
from typing import Iterable
import pytest

from functools import partial
from concurrent.futures import ThreadPoolExecutor, as_completed

import test_tools as tt

import shared_tools.complex_networks_helper_functions as sh
from haf_local_tools import haf_app

memo_cnt            = 0

def haf_app_processor(identifier, before_kill_time_min, before_kill_time_max):
    while True:
        _app = haf_app(identifier, before_kill_time_min, before_kill_time_max)
        tt.logger.info( f"app runs: {identifier}")
        _app.run()

def trx_creator(wallet):
    global memo_cnt
    while True:
        wallet.api.transfer_nonblocking('initminer', 'null', tt.Asset.Test(1), str(memo_cnt))
        memo_cnt += 1

@pytest.mark.skip(reason='https://gitlab.syncad.com/hive/haf/-/issues/118')
def test_many_forks_node_with_time_offset(prepared_networks_and_database_4_4_4_4_4):

    tt.logger.info(f'Start test_many_forks_many_ops')

    networks_builder, session = prepared_networks_and_database_4_4_4_4_4

    haf_app.setup(session, Path(__file__).parent.absolute() / ".." / ".." / ".." / ".." / "src" / "hive_fork_manager" / "doc" / "applications")

    node_under_test = networks_builder.networks[1].node('ApiNode0')
    beta_wallet = tt.Wallet(attach_to = node_under_test)

    tt.logger.info(f'Before disconnecting...')
    cnt = 0
    _futures = []
    _push_threads = 2
    _app_threads  = 8
    with ThreadPoolExecutor(max_workers = _push_threads + _app_threads ) as executor:
        for i in range(_push_threads):
            _futures.append(executor.submit(trx_creator, beta_wallet))

        for i in range(_app_threads):
            _futures.append(executor.submit(haf_app_processor, i, 1, 5 ))

    for future in as_completed(_futures):
        future.result()
