from sqlalchemy.orm.session import sessionmaker

from test_tools import logger
from local_tools import run_networks, run_networks, wait_for_irreversible_progress, get_irreversible_block, create_app, update_app_continuously, wait_for_application_context


START_TEST_BLOCK = 108
APPLICATION_CONTEXT = "trx_histogram"


def test_application_broken(world_with_witnesses_and_database):
    logger.info(f'Start test_application_broken')

    # GIVEN
    world, session, Base = world_with_witnesses_and_database
    second_session = sessionmaker()(bind = session.get_bind())
    node_under_test = world.network('Beta').node('NodeUnderTest')
    irreversible_data = Base.classes.irreversible_data
    blocks_reversible = Base.classes.blocks_reversible

    # WHEN
    run_networks(world)
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)

    # system under test
    create_app(second_session, APPLICATION_CONTEXT)

    blocks_range = session.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone()
    (first_block, last_block) = blocks_range

    session.execute( "SELECT hive.app_context_detach( '{}' )".format( APPLICATION_CONTEXT ) )
    session.execute( "SELECT public.update_histogram( {}, {} )".format( first_block, last_block ) )
    session.execute( "SELECT hive.app_context_attach( '{}', {} )".format( APPLICATION_CONTEXT, last_block ) )
    session.commit()
    
    # THEN
    with update_app_continuously(second_session, APPLICATION_CONTEXT):
        wait_for_irreversible_progress(node_under_test, START_TEST_BLOCK)
        wait_for_application_context(session)

    # application is not updated (=broken)
    wait_for_irreversible_progress(node_under_test, START_TEST_BLOCK+3)

    irreversible_block = get_irreversible_block(node_under_test)
    logger.info(f'irreversible_block {irreversible_block}')

    haf_irreversible = session.query(irreversible_data).one()
    logger.info(f'consistent_block {haf_irreversible.consistent_block}')

    blks = session.query(blocks_reversible).order_by(blocks_reversible.num).all()
    block_min = min([block.num for block in blks])
    logger.info(f'min of blocks_reversible is {block_min}')

    assert irreversible_block == haf_irreversible.consistent_block
    assert irreversible_block == block_min

