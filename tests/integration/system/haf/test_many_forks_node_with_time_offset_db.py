from pathlib import Path
import pytest
import loguru
from concurrent.futures import ThreadPoolExecutor
import time

import test_tools as tt

import shared_tools.complex_networks_helper_functions as sh
from haf_local_tools import haf_app, wait_for_irreversible_progress, get_irreversible_block, wait_for_irreversible_in_database

# Exception for handling TAPOS (Transaction as Proof of Stake) validation errors
# that occur when a transaction references a block that no longer exists due to a fork
try:
    from beekeepy._exceptions.overseer import ErrorInResponseError
except ImportError:
    from beekeepy.exceptions import ErrorInResponseError

# CommunicationError occurs when a node is temporarily unreachable during fork scenarios
try:
    from beekeepy._exceptions.base import CommunicationError
except ImportError:
    from beekeepy.exceptions import CommunicationError

memo_cnt            = 0

break_cnt           = 0
break_limit         = 250

def generate_break(wallet: tt.Wallet, node: tt.ApiNode, identifier: int):
    global break_cnt
    global break_limit

    while break_cnt < break_limit:
        sh.info("m4", wallet)
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

def trx_creator(wallet: tt.Wallet, identifier: int, start_memo: int, last_memo: int):
    max_retries = 3
    for memo in range(start_memo, last_memo):
        for attempt in range(max_retries):
            try:
                wallet.api.transfer_nonblocking('initminer', 'null', tt.Asset.Test(1), str(memo))
                break  # Success, move to next memo
            except ErrorInResponseError as e:
                # TAPOS exception occurs when the referenced block no longer exists due to a fork
                # This is expected behavior during fork scenarios - retry with fresh block reference
                if 'tapos' in str(e).lower() and attempt < max_retries - 1:
                    tt.logger.warning(f'[trx_creator {identifier}] TAPOS exception on memo {memo}, retrying (attempt {attempt + 1}/{max_retries})')
                    time.sleep(0.1)  # Brief delay to allow fork resolution
                    continue
                raise  # Re-raise if not TAPOS or max retries exceeded
            except CommunicationError as e:
                # Node may be temporarily unreachable during fork resolution
                if attempt < max_retries - 1:
                    tt.logger.warning(f'[trx_creator {identifier}] Communication error on memo {memo}, retrying (attempt {attempt + 1}/{max_retries}): {e}')
                    time.sleep(0.5)  # Longer delay for node recovery
                    continue
                raise  # Re-raise if max retries exceeded
    return f'[break {identifier}] Creating transactions finished...'

#Some information in: https://gitlab.syncad.com/hive/haf/-/issues/118
def test_many_forks_node_with_time_offset_db(prepared_networks_and_database_4_4_4_4_4):
    loguru.logger.enable("helpy")
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
        step = break_limit // _push_threads
        for i in range(_push_threads):
            start_memo = step * i
            last_memo = start_memo + step
            _futures.append(executor.submit(trx_creator, beta_wallet, i, start_memo, last_memo))

        for i in range(_app_threads):
            _futures.append(executor.submit(haf_app_processor, 1, 5, i))

        _futures.append(executor.submit(generate_break, beta_wallet, node_under_test, 0))

    tt.logger.info("results:")
    for future in _futures:
        tt.logger.info(f'{future.result()}')

    # Wait for the database to be properly synchronized before test cleanup
    # This ensures all pending operations are flushed and prevents race conditions
    # during session/database cleanup (fixes issue #251)
    final_irreversible_block = get_irreversible_block(node_under_test)
    tt.logger.info(f'Waiting for irreversible block {final_irreversible_block} to be processed by node...')
    wait_for_irreversible_progress(node_under_test, final_irreversible_block)
    # Also wait for the block to actually be written to the HAF database
    # The node may report the block as irreversible before HAF finishes writing it
    tt.logger.info(f'Waiting for irreversible block {final_irreversible_block} to be written to HAF database...')
    wait_for_irreversible_in_database(session, final_irreversible_block, timeout=60.0)

