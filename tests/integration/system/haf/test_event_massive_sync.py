from pathlib import Path

from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm.exc import MultipleResultsFound

import test_tools as tt

from local_tools import run_networks


MASSIVE_SYNC_BLOCK_NUM = 105


def test_event_massive_sync(prepared_networks_and_database):
    tt.logger.info(f'Start test_event_massive_sync')

    # GIVEN
    networks, session, Base = prepared_networks_and_database
    node_under_test = networks['Beta'].node('ApiNode0')

    events_queue = Base.classes.events_queue
    for node in networks["Alpha"].nodes + networks["Beta"].nodes:
        node.config.enable_fast_confirm = False

    # WHEN
    run_networks(networks)

    # THEN
    tt.logger.info(f'Checking that event MASSIVE_SYNC is in database')
    try:
        event = session.query(events_queue).filter(events_queue.event == 'MASSIVE_SYNC').one()
        assert event.block_num == MASSIVE_SYNC_BLOCK_NUM

    except MultipleResultsFound:
        tt.logger.error(f'Multiple events MASSIVE_SYNC in database.')
        raise

    except NoResultFound:
        tt.logger.error(f'Event MASSIVE_SYNC not in database.')
        raise
