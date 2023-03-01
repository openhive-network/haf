import os
import subprocess
import time
import random
from pathlib import Path
from typing import Iterable

from functools import partial
from concurrent.futures import ThreadPoolExecutor, as_completed

import test_tools as tt

from haf_local_tools import prepare_networks

import shared_tools.complex_networks_helper_functions as sh

START_TEST_BLOCK    = 108
memo_cnt            = 0
cnt                 = 0

class haf_app:

    root_path       = None
    postgres_url    = None
    database_name   = None

    def __init__(self, identifier):
        self.pid = None
        self.identifier = identifier
        self.args       = []

        self.create_args()

    def process_env_vars(session):
        haf_app.root_path       = os.getenv('HAF_APP_ROOT_PATH')
        haf_app.postgres_url    = os.getenv('HAF_APP_POSTGRES_URL')
        haf_app.database_name   = str(session.get_bind().url)
        haf_app.database_name   = haf_app.database_name[len('postgresql:///') : len(haf_app.database_name)]

        return haf_app.root_path is not None and haf_app.postgres_url is not None

    def create_args(self):
        assert haf_app.root_path is not None and haf_app.postgres_url is not None

        self.args.append("./haf_memo_scanner.py")
        self.args.append("--scanner-name")
        self.args.append(f"memo_scanner_{self.identifier}")
        self.args.append("--url")
        self.args.append(f"{haf_app.postgres_url}/{haf_app.database_name}")
        self.args.append("--range-block")
        self.args.append("1")
        self.args.append("--massive-threshold")
        self.args.append("1000000")
        self.args.append("--searched-item")
        self.args.append(f"{self.identifier}")

    def run(self):

        global cnt

        _after_kill_time    = 2
        _before_kill_time   = random.randint( 5, 30 )

        tt.logger.info( f"Before opening file" )
        with open( Path(f'{self.identifier}.log'), "a") as dump_file:
            cnt += 1

            try:
                tt.logger.info( f"Start app: id: {self.identifier } before time: {_before_kill_time} {haf_app.root_path} {self.args}")
                _process = subprocess.Popen( self.args, cwd = haf_app.root_path, stdout = dump_file, stderr = subprocess.STDOUT )
                self.pid = _process.pid
                tt.logger.info( f"app started: id: {self.identifier} pid: {self.pid}")
            except Exception as ex:
                tt.logger.info( f"app start problem: {ex}")

            time.sleep( _before_kill_time )

            tt.logger.info( f"before kill: cnt: {cnt} before time: {_before_kill_time} [s] id: {self.pid}" )
            _command = "kill -2 " + str( self.pid )
            try:
                os.system( _command )
            except Exception as ex:
                tt.logger.info( f"kill problem: {ex}")

            tt.logger.info( f"after kill: {_command}")

            time.sleep( _after_kill_time )

def haf_app_processor(identifier):
    while True:
        _app = haf_app(identifier)
        tt.logger.info( f"app runs: {identifier}")
        _app.run()

def fork_activator(networks: Iterable[tt.Network], logs, majority_api_node, _m, _M):
    _cnt = 1

    while True:
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

def trx_creator(wallet):
    global memo_cnt
    while True:
        wallet.api.transfer_nonblocking('initminer', 'null', tt.Asset.Test(1), str(memo_cnt))
        memo_cnt += 1

def test_many_forks_many_ops(prepared_networks_and_database_17_3):

    tt.logger.info(f'Start test_many_forks_many_ops')

    networks_builder, session = prepared_networks_and_database_17_3

    if not haf_app.process_env_vars(session):
        tt.logger.info('Variables must be set: HAF_APP_ROOT_PATH, HAF_APP_POSTGRES_URL')
        exit(1)

    majority_api_node = tt.ApiNode(network=networks_builder.networks[0])
    minority_api_node = networks_builder.networks[1].node('ApiNode0')

    prepare_networks(networks_builder.networks)
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
    while True:
        sh.wait(1, logs, majority_api_node)

        cnt += 1
        if cnt > blocks_before_disconnect:
            if sh.get_last_irreversible_block_num(_M) == sh.get_last_irreversible_block_num(_m):
                break

    _futures = []
    _fork_threads = 1
    _push_threads = 2
    _app_threads  = 1
    with ThreadPoolExecutor(max_workers = _fork_threads + _push_threads + _app_threads ) as executor:
        _futures.append(executor.submit(fork_activator, networks_builder.networks, logs, majority_api_node, _m, _M))

        for i in range(_push_threads):
            if i % 2 == 0:
                _futures.append(executor.submit(trx_creator, majority_wallet))
            else:
                _futures.append(executor.submit(trx_creator, minority_wallet))

        for i in range(_app_threads):
            _futures.append(executor.submit(haf_app_processor, i ))

    for future in as_completed(_futures):
        future.result()
