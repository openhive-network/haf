from sqlalchemy.orm.session import sessionmaker
from sqlalchemy.sql import text

import test_tools as tt

from haf_local_tools import wait_for_irreversible_progress, get_irreversible_block, create_app
from haf_local_tools.tables import BlocksReversible, IrreversibleData
from haf_local_tools import wait_for_irreversible_in_database



#replay_all_nodes==false and TIMEOUT==300s therefore START_TEST_BLOCK has to be less than 100 blocks 
START_TEST_BLOCK = 50

CONTEXT_ATTACH_BLOCK = 40
APPLICATION_CONTEXT = "application"


def update_app_continuously(session, application_context, cycles):
    for i in range(cycles):
        blocks_range = session.execute( text("SELECT * FROM hive.app_next_block( '{}' )".format( application_context )) ).fetchone()
        (first_block, last_block) = blocks_range
        if last_block is None:
            tt.logger.info( "next blocks_range was NULL\n" )
            continue
        tt.logger.info( "next blocks_range: {}\n".format( blocks_range ) )
        session.execute( text("SELECT public.update_histogram( {}, {} )".format( first_block, last_block )) )
        session.commit()
        ctx_stats = session.execute( text("SELECT current_block_num, irreversible_block FROM hafd.contexts WHERE NAME = '{}'".format( application_context )) ).fetchone()
        tt.logger.info(f'ctx_stats-update-app: cbn {ctx_stats[0]} irr {ctx_stats[1]}')


def test_application_broken(prepared_networks_and_database_12_8_without_block_log):
    tt.logger.info(f'Start test_application_broken')


    #What is tested?
        #UPDATE hafd.contexts
        #SET irreversible_block = _new_irreversible_block
        #WHERE current_block_num <= irreversible_block;
    #(SQL function: hive.remove_obsolete_reversible_data)

    #Important:
    #The value of `current_block_num` has to be less than `irreversible_block`.

    #Scenario
    #A context executes some `hive.app_next_block` and after that stays in 'broken' state. It means, that a context is still attached, but nothing happens.

    #Result
    #Finally a value of `irreversible_block` for given context has to be equal to current value of `irreversible_block` in HAF.

    # GIVEN
    networks_builder, session = prepared_networks_and_database_12_8_without_block_log
    second_session = sessionmaker()(bind=session.get_bind())
    node_under_test = networks_builder.networks[1].node('ApiNode0')

    # WHEN
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)

    # system under test
    create_app(second_session, APPLICATION_CONTEXT)

    blocks_range = session.execute( text("SELECT * FROM hive.app_next_block( '{}' )".format( APPLICATION_CONTEXT )) ).fetchone()
    (first_block, last_block) = blocks_range
    # Last event in `events_queue` == `NEW_IRREVERSIBLE` (before it was `NEW_BLOCK`) therefore first call `hive.app_next_block` returns {None, None}
    if first_block is None:
        blocks_range = session.execute( text("SELECT * FROM hive.app_next_block( '{}' )".format( APPLICATION_CONTEXT )) ).fetchone()
        (first_block, last_block) = blocks_range

    tt.logger.info(f'first_block: {first_block}, last_block: {last_block}')

    ctx_stats = session.execute( text("SELECT current_block_num, irreversible_block FROM hafd.contexts WHERE NAME = '{}'".format( APPLICATION_CONTEXT )) ).fetchone()
    tt.logger.info(f'ctx_stats-before-detach: cbn {ctx_stats[0]} irr {ctx_stats[1]}')

    session.execute( text("SELECT hive.app_context_detach( '{}' )".format( APPLICATION_CONTEXT )) )
    session.execute( text("SELECT public.update_histogram( {}, {} )".format( first_block, CONTEXT_ATTACH_BLOCK )) )
    session.execute( text("SELECT hive.app_set_current_block_num( '{}', {} )".format( APPLICATION_CONTEXT, CONTEXT_ATTACH_BLOCK )) )
    session.execute( text("SELECT hive.app_context_attach( '{}' )".format( APPLICATION_CONTEXT )) )
    session.commit()

    ctx_stats = session.execute( text("SELECT current_block_num, irreversible_block FROM hafd.contexts WHERE NAME = '{}'".format( APPLICATION_CONTEXT )) ).fetchone()
    tt.logger.info(f'ctx_stats-after-attach: cbn {ctx_stats[0]} irr {ctx_stats[1]}')

    # THEN
    nr_cycles = 10
    update_app_continuously(second_session, APPLICATION_CONTEXT, nr_cycles)
    wait_for_irreversible_progress(node_under_test, START_TEST_BLOCK)

    ctx_stats = session.execute( text("SELECT current_block_num, irreversible_block FROM hafd.contexts WHERE NAME = '{}'".format( APPLICATION_CONTEXT )) ).fetchone()
    tt.logger.info(f'ctx_stats-after-waiting: cbn {ctx_stats[0]} irr {ctx_stats[1]}')

    wait_for_irreversible_in_database(session, START_TEST_BLOCK+3)

    # application is not updated (=broken)
    #wait_for_irreversible_progress(node_under_test, START_TEST_BLOCK+3)

    # now in first move the app will update its irreversible
    irreversible_block = get_irreversible_block(node_under_test)
    tt.logger.info(f'irreversible_block {irreversible_block}')

    # first eats irreversible event and return null
    nr_cycles = 1
    ctx_stats = None
    update_app_continuously(second_session, APPLICATION_CONTEXT, nr_cycles)
    assert  ctx_stats is None

    # now moves to block=50
    nr_cycles = 1
    update_app_continuously(second_session, APPLICATION_CONTEXT, nr_cycles)

    ctx_stats = session.execute( text("SELECT current_block_num, irreversible_block FROM hafd.contexts WHERE NAME = '{}'".format( APPLICATION_CONTEXT )) ).fetchone()
    tt.logger.info(f'ctx_stats-after-waiting-2: cbn {ctx_stats[0]} irr {ctx_stats[1]}')

    haf_irreversible = session.query(IrreversibleData).one()
    tt.logger.info(f'consistent_block {haf_irreversible.consistent_block}')

    context_irreversible_block = session.execute( text("SELECT irreversible_block FROM hafd.contexts WHERE NAME = '{}'".format( APPLICATION_CONTEXT )) ).fetchone()[0]
    tt.logger.info(f'context_irreversible_block {context_irreversible_block}')

    assert irreversible_block == haf_irreversible.consistent_block
    assert irreversible_block == context_irreversible_block

    # now when the app was moved forward, hived will be able to remove reversible data with next new irreversible event
    wait_for_irreversible_in_database(session, START_TEST_BLOCK+4)

    blks = session.query(BlocksReversible).order_by(BlocksReversible.num).all()
    if len(blks) == 0:
        tt.logger.info(f'OBI can make an immediate irreversible block, so all reversible data can be cleared out')
    else:
        block_min = min([block.num for block in blks])
        tt.logger.info(f'min of blocks_reversible is {block_min}')

