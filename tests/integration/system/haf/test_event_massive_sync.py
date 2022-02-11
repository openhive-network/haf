from pathlib import Path
from sqlalchemy.orm.exc import NoResultFound
from sqlalchemy.orm.exc import MultipleResultsFound

from test_tools import logger, BlockLog
from local_tools import get_time_offset_from_file
from tables import EventsQueue


MASSIVE_SYNC_BLOCK_NUM = 105


def test_event_massive_sync(world_with_witnesses_and_database):
    logger.info(f'Start test_event_massive_sync')

    # GIVEN
    world, session = world_with_witnesses_and_database

    node_under_test = world.network('Beta').node('NodeUnderTest')
    time_offset = get_time_offset_from_file(Path().resolve()/'timestamp')
    block_log = BlockLog(None, Path().resolve()/'block_log', include_index=False)

    # WHEN
    logger.info('Running node...')
    node_under_test.run(wait_for_live=False, replay_from=block_log, time_offset=time_offset)
    # TODO get_p2p_endpoint is workaround to check if replay is finished
    node_under_test.get_p2p_endpoint()

    # THEN
    logger.info(f'Checking that event MASSIVE_SYNC is in database')
    try:
        event = session.query(EventsQueue).filter(EventsQueue.event == 'MASSIVE_SYNC').one()
        assert event.block_num == MASSIVE_SYNC_BLOCK_NUM

    except MultipleResultsFound:
        logger.error(f'Multiple events MASSIVE_SYNC in database.')
        raise

    except NoResultFound:
        logger.error(f'Event MASSIVE_SYNC not in database.')
        raise
