import datetime
import json
import time

import test_tools as tt

from haf_local_tools.tables import Blocks, Operations


def prepare_network_with_init_node_and_api_node(session, witnesses: str):
    witness_node = tt.RawNode()
    witness_node.config.witness = witnesses
    witness_node.config.private_key = '5JNHfZYKGaomSFvd4NUdQ9qMcEAC43kujbfjueTHpVapX1Kzq2n'
    witness_node.config.shared_file_size = '2G'
    witness_node.config.enable_stale_production = True
    witness_node.config.required_participation = 0
    witness_node.config.plugin = 'condenser_api database_api block_api market_history_api network_broadcast_api witness account_by_key account_by_key_api wallet_bridge_api sql_serializer'
    witness_node.config.psql_url = str(session.get_bind().url)

    api_node = tt.RawNode()
    api_node.config.shared_file_size = '2G'
    api_node.config.plugin.append('sql_serializer')
    api_node.config.psql_url = str(session.get_bind().url)

    return witness_node, api_node


def test_replay(database):
    session = database('postgresql://dev@172.17.0.1:5432/haf_block_log')

    max_years = 292  # Ref: https://github.com/python/cpython/blob/889b0b9bf95651fc05ad532cc4a66c0f8ff29fc2/Include/cpython/pytime.h
    sleep_time = datetime.timedelta(days=max_years * 365).total_seconds()
    witnesses = ["steemit18", "sminer4", "hanyuu", "debruyne", "steemit16", "sminer36", "steemit", "sminer50",
                 "mottler-6", "sminer38", "binaryfate", "sminer48", "sminer37", "sminer5", "steemit17", "steemit1",
                 "sminer39", "moderator", "sminer49"]
    raw_node = tt.RawNode()
    path = '/workspace/haf/tests/integration/system/haf/mirrornet_tests/block_log_100k/block_log'
    raw_node.config.witness = witnesses
    raw_node.config.private_key = '5JNHfZYKGaomSFvd4NUdQ9qMcEAC43kujbfjueTHpVapX1Kzq2n'
    raw_node.config.shared_file_size = '20G'
    raw_node.config.enable_stale_production = True
    # raw_node.config.transaction_status_track_after_block = '54500000'
    raw_node.config.required_participation = 0
    raw_node.config.plugin = 'sql_serializer database_api block_api account_history_api market_history_api network_broadcast_api witness account_by_key account_by_key_api wallet_bridge_api'
    raw_node.config.plugin.append('sql_serializer')
    raw_node.config.psql_url = str(session.get_bind().url)
    timestamp_origin = '@2016-09-15 19:47:24'
    timestamp_blok_100k = '@2016-03-28 04:07:21'
    raw_node.run(replay_from=path, time_offset=timestamp_blok_100k, wait_for_live=True, timeout=sleep_time,
                 arguments=['--chain-id', '42', '--skeleton-key',
                            '5JNHfZYKGaomSFvd4NUdQ9qMcEAC43kujbfjueTHpVapX1Kzq2n'])

    time.sleep(200)


def test_replay_2(database):
    session = database('postgresql://dev@172.17.0.1:5432/haf_block_log')

    timestamp_origin = '@2016-09-15 19:47:24'
    timestamp_blok_100k = '@2016-03-28 04:07:21'

    witnesses_5m = ["rabbit-70", "kushed", "delegate.lafona", "wackou", "complexring", "jesta", "xeldal", "riverhead",
                    "clayop", "steemed", "smooth.witness", "ihashfury", "joseph", "datasecuritynode", "boatymcboatface",
                    "steemychicken1", "roadscape", "pharesim", "abit", "blocktrades", "arhag", "bitcube", "witness.svk",
                    "gxt-1080-sc-0003", "steve-walschot", "bhuz", "liondani", "rabbit-63", "pfunk"]
    witnesses_100k = ["steemit18", "sminer4", "hanyuu", "debruyne", "steemit16", "sminer36", "steemit", "sminer50",
                      "mottler-6", "sminer38", "binaryfate", "sminer48", "sminer37", "sminer5", "steemit17", "steemit1",
                      "sminer39", "moderator", "sminer49"]

    path_block_log_5m = '/workspace/haf/tests/integration/system/haf/mirrornet_tests/block_log_5m/block_log'
    path_block_log_3m = '/workspace/haf/tests/integration/system/haf/mirrornet_tests/block_log_3m/block_log'
    path_block_log_50k = '/workspace/haf/tests/integration/system/haf/mirrornet_tests/block_log_50k/block_log'
    path_block_log_100k = '/workspace/haf/tests/integration/system/haf/mirrornet_tests/block_log_100k/block_log'

    max_years = 292  # Ref: https://github.com/python/cpython/blob/889b0b9bf95651fc05ad532cc4a66c0f8ff29fc2/Include/cpython/pytime.h
    sleep_time = datetime.timedelta(days=max_years * 365).total_seconds()

    witnesses_node, api_node = prepare_network_with_init_node_and_api_node(session, witnesses=witnesses_100k)

    witnesses_node.run(replay_from=path_block_log_100k, time_offset=timestamp_blok_100k, wait_for_live=True,
                       timeout=sleep_time, arguments=['--chain-id', '42', '--skeleton-key',
                                                      '5JNHfZYKGaomSFvd4NUdQ9qMcEAC43kujbfjueTHpVapX1Kzq2n'])

    ops = session.query(Operations).filter(Operations.block_num == 10000).all()
    types = [json.loads(op.body) for op in ops]

    assert types == transactions

transactions = [
  {
    'type': 'pow_operation',
    'value': {
      'worker_account': 'steemit59',
      'block_id': '0000270f6b797aa3245e6fb35a164e2c56ca0ad9',
      'nonce': '2069557240858032527',
      'work': {
        'worker': 'STM6LLegbAgLAy28EHrffBVuANFWcFgmqRMW13wBmTExqFE9SCkg4',
        'input': '1125c3ab09a55396c55ed60283cd6634d455d7bc1b9efb169952c654923e9f7e',
        'signature': '20194bba7b31c53f7bc74efd9d0524e71ae87e4b60072313d866dac4c722c30da8365c3c28c972f8b06892cf1c60703d4abf550c24f66098e57a7f9671b41caf42',
        'work': '0000000435a0bfad8471034a209d7556b4c16d77b22a66970de224f6fedad95a'
      },
      'props': {
        'account_creation_fee': {
          'amount': '100000',
          'precision': 3,
          'nai': '@@000000021'
        },
        'maximum_block_size': 131072,
        'hbd_interest_rate': 1000
      }
    }
  },
  {
    'type': 'pow_reward_operation',
    'value': {
      'worker': 'itsascam',
      'reward': {
        'amount': '21000',
        'precision': 3,
        'nai': '@@000000021'
      }
    }
  },
  {
    'type': 'producer_reward_operation',
    'value': {
      'producer': 'itsascam',
      'vesting_shares': {
        'amount': '1000',
        'precision': 3,
        'nai': '@@000000021'
      }
    }
  }
]