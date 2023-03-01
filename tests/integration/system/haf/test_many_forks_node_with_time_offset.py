import random

import test_tools as tt

from haf_local_tools import prepare_networks

START_TEST_BLOCK = 1000000

def prepare_time_offsets(limit: int):
    time_offsets = []

    for i in range(limit):
        time_offsets.append(random.randint(0, 3))

    result = ",".join(str(time_offset) for time_offset in time_offsets)
    tt.logger.info( f"Generated: {result}" )

    return time_offsets

def test_many_forks_node_with_time_offset(prepared_networks_and_database_4_4_4_4_4):

    tt.logger.info(f'Start test_many_forks_node_with_time_offset')

    networks_builder, session = prepared_networks_and_database_4_4_4_4_4

    node_under_test = networks_builder.networks[1].node('ApiNode0')

    time_offsets = prepare_time_offsets(len(networks_builder.nodes))

    prepare_networks(networks_builder.networks, True, time_offsets)
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)