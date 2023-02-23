import time

import test_tools as tt
import datetime

def test_replay_and_p2p_sync():
    max_years = 292  # Ref: https://github.com/python/cpython/blob/889b0b9bf95651fc05ad532cc4a66c0f8ff29fc2/Include/cpython/pytime.h
    sleep_time = datetime.timedelta(days=max_years * 365).total_seconds()
    #witnesses = ["rabbit-70", "kushed", "delegate.lafona", "wackou", "complexring", "jesta", "xeldal", "riverhead", "clayop", "steemed", "smooth.witness", "ihashfury", "joseph", "datasecuritynode", "boatymcboatface", "steemychicken1", "roadscape", "pharesim", "abit", "blocktrades", "arhag", "bitcube", "witness.svk", "gxt-1080-sc-0003", "steve-walschot", "bhuz", "liondani", "rabbit-63", "pfunk"]
    witnesses = ["steemit18", "sminer4", "hanyuu", "debruyne", "steemit16", "sminer36", "steemit", "sminer50", "mottler-6", "sminer38", "binaryfate", "sminer48", "sminer37", "sminer5", "steemit17", "steemit1", "sminer39", "moderator", "sminer49"]
    raw_node = tt.RawNode()
    path_block_log_5m = '/workspace/haf/tests/integration/system/haf/mirrornet_tests/block_log_100k/block_log'
    path_block_log_3m = '/workspace/haf/tests/integration/system/haf/mirrornet_tests/block_log_50k/block_log'
    raw_node.config.witness = witnesses
    raw_node.config.private_key = '5JNHfZYKGaomSFvd4NUdQ9qMcEAC43kujbfjueTHpVapX1Kzq2n'
    raw_node.config.shared_file_size = '20G'
    raw_node.config.enable_stale_production = True
    # raw_node.config.transaction_status_track_after_block = '54500000'
    raw_node.config.required_participation = 0
    # raw_node.config.plugin = 'database_api block_api account_history_api market_history_api network_broadcast_api witness account_by_key account_by_key_api wallet_bridge_api'

    raw_node.run(replay_from=path_block_log_5m, time_offset='@2016-09-15 19:47:24', wait_for_live=True, timeout=sleep_time, arguments=['--chain-id', '42', '--skeleton-key', '5JNHfZYKGaomSFvd4NUdQ9qMcEAC43kujbfjueTHpVapX1Kzq2n'])

    # raw_node.wait_number_of_blocks(2)

    api_node = tt.ApiNode()
    connect_nodes(raw_node, api_node)
    api_node.config.shared_file_size = '20G'

    api_node.run(wait_for_live=True, timeout=sleep_time,  arguments=['--chain-id', '42'])

    tt.logger.info(f'raw_node last block number:  {raw_node.get_last_block_number()}')
    tt.logger.info(f'api last block number:  {api_node.get_last_block_number()}')


def connect_nodes(first_node, second_node) -> None:
    """
    This place have to be removed after solving issue https://gitlab.syncad.com/hive/test-tools/-/issues/10
    """
    from test_tools.__private.user_handles.get_implementation import get_implementation
    second_node.config.p2p_seed_node = get_implementation(first_node).get_p2p_endpoint()