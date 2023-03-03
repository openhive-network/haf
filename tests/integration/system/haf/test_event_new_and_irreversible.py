import test_tools as tt

from haf_local_tools import wait_until_irreversible

#replay_all_nodes==false and TIMEOUT==300s therefore START_TEST_BLOCK has to be less than 100 blocks 
START_TEST_BLOCK = 50

def test_event_new_and_irreversible(prepared_networks_and_database_12_8_without_block_log):
    tt.logger.info(f'Start test_event_new_and_irreversible')

    # GIVEN
    networks_builder, session = prepared_networks_and_database_12_8_without_block_log
    node_under_test = networks_builder.networks[1].node('ApiNode0')

    # WHEN
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)

    # THEN
    tt.logger.info(f'Checking that event NEW_IRREVERSIBLE and NEW_BLOCK appear in database in correct order')
    wait_until_irreversible(node_under_test, session)
