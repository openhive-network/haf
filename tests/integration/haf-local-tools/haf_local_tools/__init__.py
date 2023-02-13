import datetime
import json
import time
from pathlib import Path
from typing import Dict

import test_tools as tt
from haf_local_tools import block_logs
from haf_local_tools.tables import EventsQueue
from shared_tools.complex_networks import run_networks

BLOCKS_IN_FORK = 5
BLOCKS_AFTER_FORK = 5
WAIT_FOR_CONTEXT_TIMEOUT = 90.0


def make_fork(networks: Dict[str, tt.Network], main_chain_trxs=[], fork_chain_trxs=[]):
    alpha_net = networks['Alpha']
    beta_net = networks['Beta']
    alpha_witness_node = alpha_net.node('WitnessNode0')
    beta_witness_node = beta_net.node('WitnessNode1')

    tt.logger.info(f'Making fork at block {get_head_block(alpha_witness_node)}')

    main_chain_wallet = tt.Wallet(attach_to=alpha_witness_node)
    fork_chain_wallet = tt.Wallet(attach_to=beta_witness_node)
    fork_block = get_head_block(beta_witness_node)
    head_block = fork_block
    alpha_net.disconnect_from(beta_net)

    for trx in main_chain_trxs:
        main_chain_wallet.api.sign_transaction(trx)
    for trx in fork_chain_trxs:
        fork_chain_wallet.api.sign_transaction(trx)

    for node in [alpha_witness_node, beta_witness_node]:
        node.wait_for_block_with_number(head_block + BLOCKS_IN_FORK)
    alpha_net.connect_with(beta_net)
    for node in [alpha_witness_node, beta_witness_node]:
        node.wait_for_block_with_number(head_block + BLOCKS_IN_FORK + BLOCKS_AFTER_FORK)

    head_block = get_head_block(beta_witness_node)
    return head_block


def wait_for_irreversible_progress(node, block_num):
    tt.logger.info(f'Waiting for progress of irreversible block')
    head_block = get_head_block(node)
    irreversible_block = get_irreversible_block(node)
    tt.logger.info(f"Current head_block_number: {head_block}, irreversible_block_num: {irreversible_block}")
    while irreversible_block < block_num:
        node.wait_for_block_with_number(head_block+1)
        head_block = get_head_block(node)
        irreversible_block = get_irreversible_block(node)
        tt.logger.info(f"Current head_block_number: {head_block}, irreversible_block_num: {irreversible_block}")
    return irreversible_block, head_block


def get_head_block(node):
    head_block_number = node.api.database.get_dynamic_global_properties()["head_block_number"]
    return head_block_number


def get_irreversible_block(node):
    irreversible_block_num = node.api.database.get_dynamic_global_properties()["last_irreversible_block_num"]
    return irreversible_block_num


def prepare_networks(networks: Dict[str, tt.Network], replay_all_nodes = True):
    blocklog_directory = None
    if replay_all_nodes:
        blocklog_directory = Path(block_logs.__file__).parent

    run_networks(list(networks.values()), blocklog_directory)


def create_node_with_database(network: tt.Network, url):
    api_node = tt.ApiNode(network=network)
    api_node.config.plugin.append('sql_serializer')
    api_node.config.psql_url = str(url)
    return api_node


SQL_CREATE_AND_REGISTER_HISTOGRAM_TABLE = """
    CREATE TABLE IF NOT EXISTS public.trx_histogram(
          day DATE
        , trx INT
        , CONSTRAINT pk_trx_histogram PRIMARY KEY( day ) )
    INHERITS( hive.{} )
    """
SQL_CREATE_UPDATE_HISTOGRAM_FUNCTION = """
    CREATE OR REPLACE FUNCTION public.update_histogram( _first_block INT, _last_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
    AS
     $function$
     BEGIN
        INSERT INTO public.trx_histogram as th( day, trx )
        SELECT
              DATE(hb.created_at) as date
            , COUNT(1) as trx
        FROM hive.trx_histogram_blocks_view hb
        JOIN hive.trx_histogram_transactions_view ht ON ht.block_num = hb.num
        WHERE hb.num >= _first_block AND hb.num <= _last_block
        GROUP BY DATE(hb.created_at)
        ON CONFLICT ON CONSTRAINT pk_trx_histogram DO UPDATE
        SET
            trx = EXCLUDED.trx + th.trx
        WHERE th.day = EXCLUDED.day;
     END;
     $function$
    """


def create_app(session, application_context):
    session.execute( "SELECT hive.app_create_context( '{}' )".format( application_context ) )
    session.execute( SQL_CREATE_AND_REGISTER_HISTOGRAM_TABLE.format( application_context ) )
    session.execute( SQL_CREATE_UPDATE_HISTOGRAM_FUNCTION )
    session.commit()


def wait_until_irreversible_without_new_block(session, final_block, limit):

    assert limit > 0

    cnt = 0
    while cnt < limit:
        #wait many times to be sure that whole network is in stable state
        #Changed from 0.1s to 0.5s, because when a computer is under stress (every CPU is used 100%), better is to wait longer
        time.sleep(0.5)

         #Last event is `NEW_IRREVERSIBLE` instead of `MASSIVE_SYNC`.
        events = session.query(EventsQueue).all()

        tt.logger.info(f'number of events: {len(events)} block number of last event: {0 if len(events) == 0 else events[len(events) - 1].block_num}')

        if len(events) == 2 and events[1].block_num == final_block:
            return

        cnt += 1

    assert False, "An expected content of `events_queue` table has not been reached."


def wait_until_irreversible(node_under_test, session):
    while True:
        node_under_test.wait_number_of_blocks(1)

        #Sometimes an irreversible block is less than head block so it's necessary to try final condition many times
        head_block = get_head_block(node_under_test)
        irreversible_block = get_irreversible_block(node_under_test)

        tt.logger.info(f'head_block: {head_block} irreversible_block: {irreversible_block}')

        result = session.query(EventsQueue).\
            filter(EventsQueue.block_num == head_block).\
            all()

        if result[ len(result) - 1 ].event == 'NEW_IRREVERSIBLE':
            return


def connect_nodes(first_node, second_node) -> None:
    """
    This place have to be removed after solving issue https://gitlab.syncad.com/hive/test-tools/-/issues/10
    """
    from test_tools.__private.user_handles.get_implementation import get_implementation
    second_node.config.p2p_seed_node = get_implementation(first_node).get_p2p_endpoint()


def prepare_network_with_init_node_and_api_node(session, init_node_time_offset: str = None):
    init_node = tt.InitNode()
    init_node.run(time_offset=init_node_time_offset)

    api_node = tt.ApiNode()
    api_node.config.plugin.append('sql_serializer')
    api_node.config.psql_url = str(session.get_bind().url)

    return api_node, init_node


def prepare_and_send_transactions(node: tt.InitNode) -> [dict, dict]:
    wallet = tt.Wallet(attach_to=node)
    node.wait_for_block_with_number(5)
    transaction_0 = wallet.api.create_account('initminer', 'alice', '{}')
    node.wait_for_block_with_number(8)
    transaction_1 = wallet.api.create_account('initminer', 'bob', '{}')
    node.wait_for_irreversible_block()
    return transaction_0, transaction_1


def verify_operation_in_haf_database(operation_name: str, transactions: list, session, operations):
    query_operations = []
    for transaction in transactions:
        query_operations.append(session.query(operations).filter(operations.block_num == transaction['block_num']).all())

    types = []
    for operation in query_operations:
        types.append([json.loads(op.body)['type'] for op in operation])

    for type in types:
        assert operation_name in type


def get_absolute_head_block_time(node) -> datetime.datetime:
    head_block_num = node.api.condenser.get_dynamic_global_properties()['head_block_number']
    head_block_timestamp = node.api.block.get_block(block_num=head_block_num)['block']['timestamp']
    return tt.Time.parse(head_block_timestamp)


def set_time_to_offset(node, shift_in_time: int) -> str:
    absolute_start_time = get_absolute_head_block_time(node) + tt.Time.seconds(shift_in_time)
    return tt.Time.serialize(absolute_start_time, format_=tt.Time.TIME_OFFSET_FORMAT)


def get_operations(node, last_block: int, first_block: int = 0) -> list:
    blocks = [node.api.account_history.get_ops_in_block(block_num=i) for i in range(first_block, last_block + 1)]
    transactions = []
    for block in blocks:
        transactions.extend(block['ops'])
    return transactions


def get_operations_from_database(session, operations_marker, last_block: int) -> list:
    operations = session.query(operations_marker).filter(operations_marker.block_num <= last_block).all()
    return [json.loads(op.body)for op in operations]
