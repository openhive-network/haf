from pathlib import Path

import test_tools as tt

from local_tools import get_head_block, get_irreversible_block, run_networks
from tables import EventsQueue


START_TEST_BLOCK = 108


def test_event_after_replay(prepared_networks_and_database):
    tt.logger.info(f'Start test_event_after_replay')

    # GIVEN
    networks, session = prepared_networks_and_database
    node_under_test = networks['Beta'].node('ApiNode0')

    # WHEN
    run_networks(networks, replay_all_nodes=True)
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    previous_irreversible = get_irreversible_block(node_under_test)
    #massive_sync_block = session.query(events_queue).\
    #    filter(events_queue.event == 'MASSIVE_SYNC').one().block_num

    # THEN
    tt.logger.info(f'Checking that event NEW_IRREVERSIBLE and NEW_BLOCK appear in database in correct order')
    for _ in range(20):
        node_under_test.wait_number_of_blocks(1)
        head_block = get_head_block(node_under_test)
        irreversible_block = get_irreversible_block(node_under_test)

        #In every block comes `NEW_BLOCK` and after that `NEW_IRREVERSIBLE`.
        #Event `NEW_IRREVERSIBLE` removes unnecessary events i.e `NEW_BLOCK`
        new_block_result = session.query(EventsQueue).\
            filter(EventsQueue.event == 'NEW_BLOCK').\
            filter(EventsQueue.block_num == head_block).\
            all()

        assert len(new_block_result) == 0

        new_irreversible_result = session.query(EventsQueue).\
            filter(EventsQueue.event == 'NEW_IRREVERSIBLE').\
            filter(EventsQueue.block_num == irreversible_block).\
            all()

        assert len(new_irreversible_result) == 1
