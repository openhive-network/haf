from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm.exc import MultipleResultsFound

import test_tools as tt

from haf_local_tools import wait_until_irreversible_without_new_block

#Changed from 106 to 110, because when a computer is under stress (every CPU is used 100%), better is to wait longer
NEW_IRREVERSIBLE_BLOCK_NUM = 110

def test_event_massive_sync(prepared_networks_and_database_12_8):
    tt.logger.info(f'Start test_event_massive_sync')

    # GIVEN
    networks_builder, session = prepared_networks_and_database_12_8

    # THEN
    tt.logger.info(f'Checking if an event `NEW_IRREVERSIBLE` is in a database')
    try:
        wait_until_irreversible_without_new_block(session, NEW_IRREVERSIBLE_BLOCK_NUM, 100)
    except NoResultFound:
        tt.logger.error(f'An event `NEW_IRREVERSIBLE` not in a database.')
        raise
