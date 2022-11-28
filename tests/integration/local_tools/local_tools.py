from datetime import datetime, timezone
from pathlib import Path
from threading import Thread, Event
import time
from typing import Dict, Optional

from sqlalchemy.engine.url import URL

import test_tools as tt
from test_tools.__private.user_handles.get_implementation import get_implementation
from test_tools.__private.wait_for import wait_for_event


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


def get_time_offset_from_file(name):
    timestamp = ''
    with open(name, 'r') as f:
        timestamp = f.read()
    timestamp = timestamp.strip()
    current_time = datetime.now(timezone.utc)
    new_time = datetime.strptime(timestamp, '%Y-%m-%dT%H:%M:%S').replace(tzinfo=timezone.utc)
    difference = round(new_time.timestamp()-current_time.timestamp()) - 5 #reduce node start delay from 10s, caused test fails
    time_offset = str(difference) + 's'
    return time_offset

def get_blocklog_directory():
    return Path(__file__).parent.resolve()

def run_networks(networks: Dict[str, tt.Network], blocklog_directory=None, replay_all_nodes=True):
    if blocklog_directory is None:
        blocklog_directory = Path(__file__).parent.resolve()

    time_offset = get_time_offset_from_file(blocklog_directory/'timestamp')

    block_log = tt.BlockLog(blocklog_directory/'block_log')

    tt.logger.info('Running nodes...')

    connect_sub_networks(list(networks.values()))

    nodes = [node for network in networks.values() for node in network.nodes]
    nodes[0].run(wait_for_live=False, replay_from=block_log, time_offset=time_offset)
    endpoint = get_implementation(nodes[0]).get_p2p_endpoint()
    for node in nodes[1:]:
        node.config.p2p_seed_node.append(endpoint)
        if replay_all_nodes:
            node.run(wait_for_live=False, replay_from=block_log, time_offset=time_offset)
        else:
            node.run(wait_for_live=False, time_offset=time_offset)

    for network in networks.values():
        network.is_running = True

    deadline = time.time() + 20
    for node in nodes:
        wait_for_event(
            get_implementation(node)._Node__notifications.live_mode_entered_event,
            deadline=deadline,
            exception_message='Live mode not activated on time.'
        )


def connect_sub_networks(sub_networks : list):
    assert len(sub_networks) > 1

    current_idx = 0
    while current_idx < len(sub_networks) - 1:
        next_current_idx = current_idx + 1
        while next_current_idx < len(sub_networks):
            tt.logger.info(f"Sub network {current_idx} connected with {next_current_idx}")
            sub_networks[current_idx].connect_with(sub_networks[next_current_idx])
            next_current_idx += 1
        current_idx += 1


def create_node_with_database(url : URL, network: Optional[tt.Network] = None) -> tt.ApiNode:
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
