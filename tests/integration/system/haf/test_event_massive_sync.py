from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm.exc import MultipleResultsFound

import test_tools as tt

from local_tools import wait_until_irreversible_without_new_block, prepare_networks


NEW_IRREVERSIBLE_BLOCK_NUM = 106

def test_event_massive_sync(prepared_networks_and_database):
    tt.logger.info(f'Start test_event_massive_sync')

    # GIVEN
    networks, session, Base = prepared_networks_and_database

    # WHEN
    prepare_networks(networks)

    # THEN
    tt.logger.info(f'Checking if an event `NEW_IRREVERSIBLE` is in a database')
    try:
        wait_until_irreversible_without_new_block(session, Base, NEW_IRREVERSIBLE_BLOCK_NUM, 100)
    except NoResultFound:
        tt.logger.error(f'An event `NEW_IRREVERSIBLE` not in a database.')
        raise
