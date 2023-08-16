from sqlalchemy.orm.session import sessionmaker
from math import ceil
import threading
import subprocess
from random import uniform
from time import sleep

import test_tools as tt

from haf_local_tools import wait_for_irreversible_progress, get_irreversible_block, create_app
from haf_local_tools import get_head_block
from haf_local_tools.tables import BlocksReversible, IrreversibleData

from haf_local_tools.system.haf import (
    assert_are_blocks_sync_with_haf_db,
    assert_are_indexes_restored,
    connect_nodes,
    prepare_and_send_transactions,
)
from haf_local_tools import make_fork, wait_for_irreversible_progress
import pytest

#replay_all_nodes==false and TIMEOUT==300s therefore START_TEST_BLOCK has to be less than 100 blocks 
START_TEST_BLOCK = 111

APPLICATION_CONTEXT = "trx_histogram"



def update_app_continuously(session, application_context, cycles, node=None):
    # return 190, 200
    for i in range(cycles):
        if node:
            dgpo = node.api.database.get_dynamic_global_properties()
            tt.logger.info(f"{dgpo=}")
        blocks_range = session.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( application_context ) ).fetchone()
        (first_block, last_block) = blocks_range
        tt.logger.info( "next blocks_range: {}\n".format( blocks_range ) )
        if last_block is None:
            session.commit()
            continue
        session.execute( "SELECT public.update_histogram( {}, {} )".format( first_block, last_block ) )
        session.commit()
        ctx_stats = session.execute( "SELECT * FROM hive.contexts WHERE NAME = '{}'".format( application_context ) ).fetchone()
        tt.logger.info(f'ctx_stats-update-app: {ctx_stats}')
        ctx_stats = session.execute( "SELECT current_block_num, irreversible_block FROM hive.contexts WHERE NAME = '{}'".format( application_context ) ).fetchone()
        tt.logger.info(f'ctx_stats-update-app: cbn {ctx_stats[0]} irr {ctx_stats[1]}')
    assert cycles>0
    return blocks_range


def update_app_continuously_with_sleep(session, application_context, cycles):
    # return 190, 200
    for i in range(cycles):
        tt.logger.info('before database transaction')
        sleep_time = 60.0
        # sleep_time = uniform(0, 5)
        blocks_range = session.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( application_context ) ).fetchone()
        (first_block, last_block) = blocks_range
        tt.logger.info( "next blocks_range: {}\n".format( blocks_range ) )
        session.execute( f"SELECT pg_sleep({sleep_time})" )
        if last_block is None:
            session.commit()
            tt.logger.info(f'after database transaction, result is {blocks_range=}')
            continue
        session.execute( "SELECT public.update_histogram( {}, {} )".format( first_block, last_block ) )
        session.commit()
        tt.logger.info(f'after database transaction, result is {blocks_range=}')
        ctx_stats = session.execute( "SELECT * FROM hive.contexts WHERE NAME = '{}'".format( application_context ) ).fetchone()
        tt.logger.info(f'ctx_stats-update-app: {ctx_stats}')
        ctx_stats = session.execute( "SELECT current_block_num, irreversible_block FROM hive.contexts WHERE NAME = '{}'".format( application_context ) ).fetchone()
        tt.logger.info(f'ctx_stats-update-app: cbn {ctx_stats[0]} irr {ctx_stats[1]}')
    assert cycles>0
    return blocks_range

def get_context_events_id(session):
    contexts = session.execute( "SELECT * FROM hive.contexts" ).fetchone()
    tt.logger.info(f'contexts {contexts}')
    events_id = contexts[6]
    tt.logger.info(f'events_id {events_id}')
    return events_id


def get_next_slot_for_witness(node, witness):
    node.wait_number_of_blocks(1) # we should be at beggining of block time slot
    while True:
        head = get_head_block(node)
        tt.logger.info(f"{head=}")
        schedule = node.api.database.get_witness_schedule()
        tt.logger.info(f"{schedule=}")
        dgpo = node.api.database.get_dynamic_global_properties()
        tt.logger.info(f"{dgpo=}")

        current_witness = dgpo["current_witness"]
        tt.logger.info(f"{current_witness=}")
        scheduled_witnesses = schedule["current_shuffled_witnesses"]
        tt.logger.info(f"{scheduled_witnesses=}")

        index = scheduled_witnesses.index(witness)
        current_index = scheduled_witnesses.index(current_witness)
        tt.logger.info(f"{index=}")
        tt.logger.info(f"{current_index=}")

        is_schedule_shuffled = ceil(head/21) != ceil((head-current_index+index)/21)
        tt.logger.info(f"{index <= current_index=}")
        tt.logger.info(f"{is_schedule_shuffled=}")
        tt.logger.info(f"{head=}")
        tt.logger.info(f"{head-current_index+index=}")
        tt.logger.info(f"{ceil((head)/21)=}")
        tt.logger.info(f"{ceil((head-current_index+index)/21)=}")
        if current_index>=index or is_schedule_shuffled:
            node.wait_number_of_blocks(1)
        else:
            return - current_index + index


def restrict_connections(node_with_restrictions, allowed_nodes):
    ids = [node.api.network_node.get_info()["node_id"] for node in allowed_nodes]
    node_with_restrictions.api.network_node.set_allowed_peers(allowed_peers=ids)


# @pytest.mark.parametrize('execution_number', range(5))
def test_application_with_double_production(prepared_networks_and_database_1_2_10_8_with_double_production, extra_witness):
    tt.logger.info(f'Start test_application_with_double_production')


    #What is tested?
    #Application with contrext attached in situation of microfork

    #Scenario
    #After microfork (fork of length 1) we could flush events still referenced by hive.contexts table violating foreign key constraint

    #Result
    #No foreign key constrain violation by hived (nor application), no crash


    # GIVEN
    networks_builder, sessions = prepared_networks_and_database_1_2_10_8_with_double_production
    database_session_under_test = sessions[0]
    node_under_test = networks_builder.networks[0].node('ApiNode0')
    witness_node_0 = networks_builder.networks[0].node('WitnessNode0')
    witness_node_1 = networks_builder.networks[0].node('WitnessNode1')

    create_app(database_session_under_test, APPLICATION_CONTEXT)


    # WHEN
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)

    first_block, _ = update_app_continuously(database_session_under_test, APPLICATION_CONTEXT, START_TEST_BLOCK)
    while first_block is None or first_block < START_TEST_BLOCK:
        first_block, _ = update_app_continuously(database_session_under_test, APPLICATION_CONTEXT, 1)

    next_slot_for_witness = get_next_slot_for_witness(node_under_test, extra_witness)
    tt.logger.info(f"{extra_witness=}, {next_slot_for_witness=}")

    old_head = get_head_block(node_under_test)
    tt.logger.info(f"{old_head=}")
    tt.logger.info(f"{old_head + next_slot_for_witness-1=}")
    head = get_head_block(node_under_test)
    tt.logger.info(f"{head=}")
    while head < old_head + next_slot_for_witness-1:
        first_block, _ = update_app_continuously(database_session_under_test, APPLICATION_CONTEXT, 1)
        tt.logger.info(f"{first_block=}")
        head = get_head_block(node_under_test)
        tt.logger.info(f"{head=}")
        irr = get_irreversible_block(node_under_test)
        tt.logger.info(f"{irr=}")

    head_before_fork = get_head_block(node_under_test)
    tt.logger.info(f"{head_before_fork=}")

    tt.logger.info(f"before fork")
    restrict_connections(node_under_test, [witness_node_0])
    restrict_connections(witness_node_0, [node_under_test])
    restrict_connections(witness_node_1, [witness_node_1])

    tt.logger.info(f"before sending trx")
    wallet_0 = tt.Wallet(attach_to=node_under_test)
    wallet_0.api.create_account("initminer", "alice0", "{}")
    tt.logger.info(f"after sending trx")

    head_after_fork = get_head_block(node_under_test)
    tt.logger.info(f"{head_after_fork=}")

    witness_node_0.wait_for_block_with_number(head_before_fork+3)
    update_app_continuously(database_session_under_test, APPLICATION_CONTEXT, 40)

    restrict_connections(node_under_test, [witness_node_0, witness_node_1])
    restrict_connections(witness_node_0, [node_under_test, witness_node_1])
    restrict_connections(witness_node_1, [node_under_test, witness_node_0])
    tt.logger.info("after reconnecting witness_node_0 and witness_node_1")

    update_app_continuously(database_session_under_test, APPLICATION_CONTEXT, 4)
    witness_node_0.wait_for_block_with_number(head_before_fork+4)
    restrict_connections(node_under_test, [])
    restrict_connections(witness_node_0, [])
    restrict_connections(witness_node_1, [])
    tt.logger.info("                                                                  after reconnecting all nodes")

    # THEN
    update_app_continuously(database_session_under_test, APPLICATION_CONTEXT, 4)
    try:
        previous_events_id = None
        while True:

            new_events_id = get_context_events_id(database_session_under_test)
            tt.logger.info(f"                                                      {previous_events_id=} {new_events_id=}")

            if previous_events_id is not None and previous_events_id < new_events_id:
                tt.logger.info(f"update_app_continuously_with_sleep")
                update_app_continuously_with_sleep(database_session_under_test, APPLICATION_CONTEXT, 1)
                break
            else:
                tt.logger.info(f"update_app_continuously")
                update_app_continuously(database_session_under_test, APPLICATION_CONTEXT, 1)
            previous_events_id = new_events_id
    except KeyboardInterrupt as e:
        tt.logger.info(f"received exception {e}")
        import traceback
        error_message = traceback.format_exc()
        tt.logger.info(error_message)
        assert False, f"KeyboardInterrupt exception was raised, failing test"
