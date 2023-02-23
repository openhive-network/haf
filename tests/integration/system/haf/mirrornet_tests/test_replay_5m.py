import test_tools as tt
import datetime

def test_replay():
    max_years = 292  # Ref: https://github.com/python/cpython/blob/889b0b9bf95651fc05ad532cc4a66c0f8ff29fc2/Include/cpython/pytime.h
    sleep_time = datetime.timedelta(days=max_years * 365).total_seconds()
    witnesses = ["rabbit-70", "kushed", "delegate.lafona", "wackou", "complexring", "jesta", "xeldal", "riverhead", "clayop", "steemed", "smooth.witness", "ihashfury", "joseph", "datasecuritynode", "boatymcboatface", "steemychicken1", "roadscape", "pharesim", "abit", "blocktrades", "arhag", "bitcube", "witness.svk", "gxt-1080-sc-0003", "steve-walschot", "bhuz", "liondani", "rabbit-63", "pfunk"]
    raw_node = tt.RawNode()
    path = '/workspace/haf/tests/integration/system/haf/mirrornet_tests/block_log_5m/block_log'
    raw_node.config.witness = witnesses
    raw_node.config.private_key = '5JNHfZYKGaomSFvd4NUdQ9qMcEAC43kujbfjueTHpVapX1Kzq2n'
    raw_node.config.shared_file_size = '20G'
    raw_node.config.enable_stale_production = True
    # raw_node.config.transaction_status_track_after_block = '54500000'
    raw_node.config.required_participation = 0
    # raw_node.config.plugin = 'database_api block_api account_history_api market_history_api network_broadcast_api witness account_by_key account_by_key_api wallet_bridge_api'

    raw_node.run(replay_from=path, time_offset='@2016-09-15 19:47:24', wait_for_live=True, timeout=sleep_time, arguments=['--chain-id', '42', '--skeleton-key', '5JNHfZYKGaomSFvd4NUdQ9qMcEAC43kujbfjueTHpVapX1Kzq2n'])
