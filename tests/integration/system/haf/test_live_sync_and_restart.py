from sqlalchemy import cast
from sqlalchemy.dialects.postgresql import JSONB

import test_tools as tt

from haf_local_tools import (
    get_head_block,
    get_irreversible_block,
    wait_for_irreversible_progress,
    wait_for_irreversible_in_database,
    get_first_block_with_transaction,
    wait_for_block_in_database)
from haf_local_tools.tables import Blocks, BlocksView, Transactions, OperationsIrreversibleView


START_TEST_BLOCK =  115


def display_blocks_information(node):
    h_b = get_head_block(node)
    i_b = get_irreversible_block(node)
    tt.logger.info(f'head_block: {h_b} irreversible_block: {i_b}')
    return h_b, i_b


def test_live_sync_and_restart(prepared_networks_and_database_6_4):
    tt.logger.info(f'Start test_live_sync')

    # GIVEN
    networks_builder, session = prepared_networks_and_database_6_4
    witness_node = networks_builder.networks[0].node('WitnessNode0')
    node_under_test = networks_builder.networks[1].node('ApiNode0')
    #witness_node_n1 = networks_builder.networks[1].node('WitnessNode1')
    #witness_node_n1.close()

    print( f"MICKIEWICZ!!!:  {networks_builder.networks[0].nodes}")


    # WHEN
    wait_for_block_in_database(session, START_TEST_BLOCK)

    head_block_num = node_under_test.api.condenser.get_dynamic_global_properties()["head_block_number"]

    head_block_timestamp = node_under_test.api.block.get_block(block_num=head_block_num)["block"]["timestamp"]
    absolute_start_time = tt.Time.parse(head_block_timestamp)
    absolute_start_time -= tt.Time.seconds(5)  # Node starting and entering live mode takes some time to complete

    #wait_for_block_in_database(session, 120)

    node_under_test.restart( wait_for_live = False, time_control=tt.StartTimeControl(start_time=absolute_start_time))


    node_under_test.wait_for_block_with_number(120)

    #node_under_test.restart(time_control=tt.StartTimeControl(start_time=absolute_start_time))
