from sqlalchemy.orm.session import sessionmaker

import test_tools as tt

from local_tools import run_networks, run_networks, wait_for_irreversible_progress, get_irreversible_block, create_app


START_TEST_BLOCK = 108
CONTEXT_ATTACH_BLOCK = 50
APPLICATION_CONTEXT = "trx_histogram"


def update_app_continuously(session, application_context, cycles):
    for i in range(cycles):
        blocks_range = session.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( application_context ) ).fetchone()
        (first_block, last_block) = blocks_range
        if last_block is None:
            continue
        tt.logger.info( "next blocks_range: {}\n".format( blocks_range ) )
        session.execute( "SELECT public.update_histogram( {}, {} )".format( first_block, last_block ) )
        session.commit()
        ctx_stats = session.execute( "SELECT current_block_num, irreversible_block FROM hive.contexts WHERE NAME = '{}'".format( application_context ) ).fetchone()
        tt.logger.info(f'ctx_stats-update-app: cbn {ctx_stats[0]} irr {ctx_stats[1]}')


def test_application_broken(prepared_networks_and_database):
    tt.logger.info(f'Start test_application_broken')


    #What is tested?
        #UPDATE hive.contexts
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
    networks, session, Base = prepared_networks_and_database
    second_session = sessionmaker()(bind = session.get_bind())
    node_under_test = networks['Beta'].node('ApiNode0')
    irreversible_data = Base.classes.irreversible_data
    blocks_reversible = Base.classes.blocks_reversible

    # WHEN
    run_networks(networks, replay_all_nodes=False)
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)

    # system under test
    create_app(second_session, APPLICATION_CONTEXT)

    blocks_range = session.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone()
    (first_block, last_block) = blocks_range

    ctx_stats = session.execute( "SELECT current_block_num, irreversible_block FROM hive.contexts WHERE NAME = '{}'".format( APPLICATION_CONTEXT ) ).fetchone()
    tt.logger.info(f'ctx_stats-before-detach: cbn {ctx_stats[0]} irr {ctx_stats[1]}')

    session.execute( "SELECT hive.app_context_detach( '{}' )".format( APPLICATION_CONTEXT ) )
    session.execute( "SELECT public.update_histogram( {}, {} )".format( first_block, CONTEXT_ATTACH_BLOCK ) )
    session.execute( "SELECT hive.app_context_attach( '{}', {} )".format( APPLICATION_CONTEXT, CONTEXT_ATTACH_BLOCK ) )
    session.commit()

    ctx_stats = session.execute( "SELECT current_block_num, irreversible_block FROM hive.contexts WHERE NAME = '{}'".format( APPLICATION_CONTEXT ) ).fetchone()
    tt.logger.info(f'ctx_stats-after-attach: cbn {ctx_stats[0]} irr {ctx_stats[1]}')

    # THEN
    nr_cycles = 10
    update_app_continuously(second_session, APPLICATION_CONTEXT, nr_cycles)
    wait_for_irreversible_progress(node_under_test, START_TEST_BLOCK)

    ctx_stats = session.execute( "SELECT current_block_num, irreversible_block FROM hive.contexts WHERE NAME = '{}'".format( APPLICATION_CONTEXT ) ).fetchone()
    tt.logger.info(f'ctx_stats-after-waiting: cbn {ctx_stats[0]} irr {ctx_stats[1]}')

    # application is not updated (=broken)
    wait_for_irreversible_progress(node_under_test, START_TEST_BLOCK+3)

    ctx_stats = session.execute( "SELECT current_block_num, irreversible_block FROM hive.contexts WHERE NAME = '{}'".format( APPLICATION_CONTEXT ) ).fetchone()
    tt.logger.info(f'ctx_stats-after-waiting-2: cbn {ctx_stats[0]} irr {ctx_stats[1]}')

    irreversible_block = get_irreversible_block(node_under_test)
    tt.logger.info(f'irreversible_block {irreversible_block}')

    haf_irreversible = session.query(irreversible_data).one()
    tt.logger.info(f'consistent_block {haf_irreversible.consistent_block}')

    context_irreversible_block = session.execute( "SELECT irreversible_block FROM hive.contexts WHERE NAME = '{}'".format( APPLICATION_CONTEXT ) ).fetchone()[0]
    tt.logger.info(f'context_irreversible_block {context_irreversible_block}')

    assert irreversible_block == haf_irreversible.consistent_block
    assert irreversible_block == context_irreversible_block

    blks = session.query(blocks_reversible).order_by(blocks_reversible.num).all()
    block_min = min([block.num for block in blks])
    tt.logger.info(f'min of blocks_reversible is {block_min}')

    assert irreversible_block == haf_irreversible.consistent_block
    assert irreversible_block == block_min

