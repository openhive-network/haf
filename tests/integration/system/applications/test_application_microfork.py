from sqlalchemy.orm.session import sessionmaker
import threading
from time import sleep
from random import uniform
import pytest
import subprocess

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


def restrict_connections(node_with_restrictions, allowed_nodes):
    ids = [node.api.network_node.get_info()["node_id"] for node in allowed_nodes]
    node_with_restrictions.api.network_node.set_allowed_peers(allowed_peers=ids)


def test_application_microfork(prepared_networks_and_database_1_2_9_8):
    tt.logger.info(f'Start test_application_microfork')


    #What is tested?
    #Application with contrext attached in situation of microfork

    #Scenario
    #After microfork (fork of length 1) we could flush events still referenced by hive.contexts table violating foreign key constraint

    #Result
    #No foreign key constrain violation by hived (nor application), no crash


    # GIVEN
    networks_builder, sessions = prepared_networks_and_database_1_2_9_8
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

    head_before_fork = get_head_block(node_under_test)
    tt.logger.info(f"{head_before_fork=}")

    tt.logger.info(f"before fork")
    restrict_connections(node_under_test, [witness_node_0])
    restrict_connections(witness_node_0, [node_under_test])
    restrict_connections(witness_node_1, [witness_node_1])
    witness_node_0.wait_for_block_with_number(head_before_fork+1)


    restrict_connections(node_under_test, [witness_node_0, witness_node_1])
    restrict_connections(witness_node_0, [node_under_test, witness_node_1])
    restrict_connections(witness_node_1, [node_under_test, witness_node_0])
    tt.logger.info("after reconnecting witness_node_0 and witness_node_1")

    update_app_continuously(database_session_under_test, APPLICATION_CONTEXT, 4)
    witness_node_0.wait_for_block_with_number(head_before_fork+3)
    restrict_connections(node_under_test, [])
    restrict_connections(witness_node_0, [])
    restrict_connections(witness_node_1, [])
    tt.logger.info("                                                                  after reconnecting all nodes")
    update_app_continuously(database_session_under_test, APPLICATION_CONTEXT, 4)

    # raise KeyboardInterrupt
    # tt.logger.info(f"{1/0=}")
    # THEN
    # with pytest.raises(KeyboardInterrupt):
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
