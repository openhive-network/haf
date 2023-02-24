import datetime
import time

import test_tools as tt


def test_replay(database):
    session = database('postgresql://dev@172.17.0.1:5432/haf_block_log')

    max_years = 292  # Ref: https://github.com/python/cpython/blob/889b0b9bf95651fc05ad532cc4a66c0f8ff29fc2/Include/cpython/pytime.h
    sleep_time = datetime.timedelta(days=max_years * 365).total_seconds()
    witnesses = ["steemit18", "sminer4", "hanyuu", "debruyne", "steemit16", "sminer36", "steemit", "sminer50", "mottler-6", "sminer38", "binaryfate", "sminer48", "sminer37", "sminer5", "steemit17", "steemit1", "sminer39", "moderator", "sminer49"]
    raw_node = tt.RawNode()
    path = '/workspace/haf/tests/integration/system/haf/mirrornet_tests/block_log_100k/block_log'
    raw_node.config.witness = witnesses
    raw_node.config.private_key = '5JNHfZYKGaomSFvd4NUdQ9qMcEAC43kujbfjueTHpVapX1Kzq2n'
    raw_node.config.shared_file_size = '20G'
    raw_node.config.enable_stale_production = True
    # raw_node.config.transaction_status_track_after_block = '54500000'
    raw_node.config.required_participation = 0
    raw_node.config.plugin = 'sql_serializer database_api block_api account_history_api market_history_api network_broadcast_api witness account_by_key account_by_key_api wallet_bridge_api'
    # raw_node.config.plugin.append('sql_serializer')
    raw_node.config.psql_url = str(session.get_bind().url)

    raw_node.run(replay_from=path, time_offset='@2016-09-15 19:47:24', wait_for_live=True, timeout=sleep_time, arguments=['--chain-id', '42', '--skeleton-key', '5JNHfZYKGaomSFvd4NUdQ9qMcEAC43kujbfjueTHpVapX1Kzq2n'])
