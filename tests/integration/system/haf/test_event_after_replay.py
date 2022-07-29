from pathlib import Path

import test_tools as tt

from local_tools import get_head_block, get_irreversible_block, run_networks


START_TEST_BLOCK = 108


def test_event_after_replay(prepared_networks_and_database):
    tt.logger.info(f'Start test_event_after_replay')

    # GIVEN
    networks, session, Base = prepared_networks_and_database
    node_under_test = networks['Beta'].node('ApiNode0')

    events_queue = Base.classes.events_queue
    for node in networks["Alpha"].nodes + networks["Beta"].nodes:
        node.config.enable_fast_confirm = False

    # WHEN
    run_networks(networks, replay_all_nodes=True)
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    previous_irreversible = get_irreversible_block(node_under_test)
    massive_sync_block = session.query(events_queue).\
        filter(events_queue.event == 'MASSIVE_SYNC').one().block_num

    # THEN
    tt.logger.info(f'Checking that event NEW_IRREVERSIBLE and NEW_BLOCK appear in database in correct order')
    for _ in range(20):
        node_under_test.wait_number_of_blocks(1)
        head_block = get_head_block(node_under_test)
        irreversible_block = get_irreversible_block(node_under_test)

        if irreversible_block > previous_irreversible and irreversible_block >= massive_sync_block:
            session.query(events_queue).\
                filter(events_queue.event == 'NEW_IRREVERSIBLE').\
                filter(events_queue.block_num == irreversible_block).\
                one()

            previous_irreversible = irreversible_block

        session.query(events_queue).\
            filter(events_queue.event == 'NEW_BLOCK').\
            filter(events_queue.block_num == head_block).\
            one()

        # now check that old events were removed
        old_block_events = session.query(events_queue).\
            filter(events_queue.event == 'NEW_BLOCK').\
            filter(events_queue.block_num <= irreversible_block).\
            all()
        assert old_block_events == []

        lower_bound_event = session.query(events_queue).\
            filter(events_queue.event == 'NEW_BLOCK').\
            order_by(events_queue.id).\
            first()

        old_irreversible_events = session.query(events_queue).\
            filter(events_queue.event == 'NEW_IRREVERSIBLE').\
            filter(events_queue.id < lower_bound_event.id).\
            filter(events_queue.id > 0).\
            all()
        assert old_irreversible_events == []
