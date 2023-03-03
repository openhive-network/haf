import test_tools as tt

START_TEST_BLOCK = 1000000

def test_many_forks_node_with_time_offset(prepared_networks_and_database_4_4_4_4_4):

    tt.logger.info(f'Start test_many_forks_node_with_time_offset')

    networks_builder, session = prepared_networks_and_database_4_4_4_4_4

    node_under_test = networks_builder.networks[1].node('ApiNode0')

    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)