import test_tools as tt
import datetime
import json

from haf_local_tools import connect_nodes, get_operations, get_operations_from_database, \
    prepare_network_with_init_node_and_api_node, prepare_and_send_transactions, verify_operation_in_haf_database
from haf_local_tools.tables import Operations

def test_replay_and_p2p_sync(database):
    # session = database('postgresql://dev@172.17.0.1:5432/haf_block_log')

    max_years = 292  # Ref: https://github.com/python/cpython/blob/889b0b9bf95651fc05ad532cc4a66c0f8ff29fc2/Include/cpython/pytime.h
    sleep_time = datetime.timedelta(days=max_years * 365).total_seconds()
    witnesses = ["rabbit-70", "kushed", "delegate.lafona", "wackou", "complexring", "jesta", "xeldal", "riverhead", "clayop", "steemed", "smooth.witness", "ihashfury", "joseph", "datasecuritynode", "boatymcboatface", "steemychicken1", "roadscape", "pharesim", "abit", "blocktrades", "arhag", "bitcube", "witness.svk", "gxt-1080-sc-0003", "steve-walschot", "bhuz", "liondani", "rabbit-63", "pfunk"]
    # witnesses = ["steemit18", "sminer4", "hanyuu", "debruyne", "steemit16", "sminer36", "steemit", "sminer50", "mottler-6", "sminer38", "binaryfate", "sminer48", "sminer37", "sminer5", "steemit17", "steemit1", "sminer39", "moderator", "sminer49"]
    raw_node = tt.RawNode()
    path_block_log_5m = '/workspace/haf/tests/integration/system/haf/mirrornet_tests/block_log_5m/block_log'
    path_block_log_3m = '/workspace/haf/tests/integration/system/haf/mirrornet_tests/block_log_3m/block_log'
    raw_node.config.witness = witnesses
    raw_node.config.private_key = '5JNHfZYKGaomSFvd4NUdQ9qMcEAC43kujbfjueTHpVapX1Kzq2n'
    raw_node.config.shared_file_size = '2G'
    raw_node.config.enable_stale_production = True
    # raw_node.config.transaction_status_track_after_block = '54500000'
    raw_node.config.required_participation = 0
    raw_node.config.plugin = 'condenser_api database_api block_api market_history_api network_broadcast_api witness account_by_key account_by_key_api wallet_bridge_api'
    # raw_node.config.plugin = 'condenser_api block_api'

    raw_node.run(replay_from=path_block_log_5m, time_offset='@2016-09-15 19:47:24', wait_for_live=True, timeout=sleep_time, arguments=['--chain-id', '42', '--skeleton-key', '5JNHfZYKGaomSFvd4NUdQ9qMcEAC43kujbfjueTHpVapX1Kzq2n'])

    head_block_num = raw_node.api.condenser.get_dynamic_global_properties()['head_block_number']
    head_block_timestamp = raw_node.api.block.get_block(block_num=head_block_num)['block']['timestamp']
    absolute_start_time = tt.Time.parse(head_block_timestamp)
    # absolute_start_time -= tt.Time.seconds(5)  # Node starting and entering live mode takes some time to complete

    api_node = tt.RawNode()
    connect_nodes(raw_node, api_node)
    api_node.config.shared_file_size = '2G'
    # api_node.config.plugin.append('sql_serializer')
    # api_node.config.psql_url = str(session.get_bind().url)

    api_node.run(replay_from=path_block_log_3m, time_offset = tt.Time.serialize(absolute_start_time, format_=tt.Time.TIME_OFFSET_FORMAT), wait_for_live=True, timeout=sleep_time,  arguments=['--chain-id', '42'])

    tt.logger.info(f'raw_node last block number:  {raw_node.get_last_block_number()}')
    tt.logger.info(f'api last block number:  {api_node.get_last_block_number()}')

