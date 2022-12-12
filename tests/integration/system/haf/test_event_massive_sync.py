from pathlib import Path
import time

from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm.exc import MultipleResultsFound

import test_tools as tt

from local_tools import run_networks
from tables import EventsQueue


NEW_IRREVERSIBLE_BLOCK_NUM = 106


def test_event_massive_sync(prepared_networks_and_database):
    tt.logger.info(f'Start test_event_massive_sync')

    # GIVEN
    networks, session = prepared_networks_and_database
    node_under_test = networks['Beta'].node('ApiNode0')

    # WHEN
    run_networks(networks)

    # THEN
    tt.logger.info(f'Checking that event "NEW_IRREVERSIBLE" is in database')
    try:
        #wait 1s to be sure that whole network is in stable state
        time.sleep(1)

         #Last event is `NEW_IRREVERSIBLE` instead of `MASSIVE_SYNC`.
        events = session.query(EventsQueue).all()
        assert len(events) == 2
        assert events[1].block_num == NEW_IRREVERSIBLE_BLOCK_NUM

    except NoResultFound:
        tt.logger.error(f'Event NEW_IRREVERSIBLE not in database.')
        raise
