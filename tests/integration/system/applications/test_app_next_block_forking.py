from pathlib import Path

from test_tools import logger, Wallet, Asset
from local_tools import get_irreversible_block, get_head_block, run_networks, make_fork, wait_for_irreversible_progress, run_networks
from threading import Thread


START_TEST_BLOCK = 108

APPLICATION_CONTEXT = "trx_histogram"
SQL_CREATE_AND_REGISTER_HISTOGRAM_TABLE = """
    CREATE TABLE IF NOT EXISTS public.trx_histogram(
          day DATE
        , trx INT
        , CONSTRAINT pk_trx_histogram PRIMARY KEY( day ) )
    INHERITS( hive.{} )
    """.format( APPLICATION_CONTEXT )
SQL_CREATE_UPDATE_HISTOGRAM_FUNCTION = """
    CREATE OR REPLACE FUNCTION public.update_histogram( _first_block INT, _last_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
    AS
     $function$
     BEGIN
        INSERT INTO public.trx_histogram as th( day, trx )
        SELECT
              DATE(hb.created_at) as date
            , COUNT(1) as trx
        FROM hive.trx_histogram_blocks_view hb
        JOIN hive.trx_histogram_transactions_view ht ON ht.block_num = hb.num
        WHERE hb.num >= _first_block AND hb.num <= _last_block
        GROUP BY DATE(hb.created_at)
        ON CONFLICT ON CONSTRAINT pk_trx_histogram DO UPDATE
        SET
            trx = EXCLUDED.trx + th.trx
        WHERE th.day = EXCLUDED.day;
     END;
     $function$
    """


def test_app_next_block_forking(world_with_witnesses_and_database):
    logger.info(f'Start test_app_next_block_forking')
    # GIVEN
    world, session, Base = world_with_witnesses_and_database
    node_under_test = world.network('Beta').node('NodeUnderTest')

    # WHEN
    exist = session.execute( "SELECT hive.app_context_exists( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone()
    if exist[ 0 ] == False:
        logger.info("           -----------          hive.app_create_context")
        session.execute( "SELECT hive.app_create_context( '{}' )".format( APPLICATION_CONTEXT ) )

    # create and register a table
    session.execute( SQL_CREATE_AND_REGISTER_HISTOGRAM_TABLE )
    session.commit()

    # create SQL function to do the application's task
    session.execute( SQL_CREATE_UPDATE_HISTOGRAM_FUNCTION )
    session.commit()

    run_networks(world, Path().resolve())
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)

    wallet = Wallet(attach_to=node_under_test)
    def thread_func():
        #if random.choice([True, True, False]):
        count = 0
        while True:
            wallet.api.transfer('initminer', 'initminer', Asset.Test(1000), 'dummy transfer operation')
            count = count + 1 
            logger.info(f'------------------ sent {count} transaction by {wallet}')
    Thread(daemon=True, target=thread_func).start()

    head_block = get_head_block(node_under_test)
    irreversible = get_irreversible_block(node_under_test)

    blocks_range = session.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone()
    session.commit()
    (first_block, last_block) = blocks_range

    blocks_range = session.execute( "SELECT hive.app_context_detach( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone()
    session.commit()
    blocks_range = session.execute( "SELECT hive.app_context_detached_save_block_num( '{}', {} )".format( APPLICATION_CONTEXT, last_block ) ).fetchone()
    session.commit()
    blocks_range = session.execute( "SELECT hive.app_context_attach( '{}', {} )".format( APPLICATION_CONTEXT, last_block ) ).fetchone()
    session.commit()



    # THEN
    logger.info("Application created, infinite loop")
    while True:

        head_block = get_head_block(node_under_test)
        irreversible = get_irreversible_block(node_under_test)
        if head_block > 140:
            break
        logger.info( ">>>>>>>>>>>> Head block {}".format( head_block ) )
        logger.info( ">>>>>>>>>>>> Irreversible block {}".format( irreversible ) )


        blocks_range = session.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone()
        session.commit()
        (first_block, last_block) = blocks_range
        logger.info( "Blocks range {}".format( blocks_range ) )

        # if no blocks are fetched then ask for new blocks again
        if not first_block:
            continue
        session.execute( "SELECT public.update_histogram( {}, {} )".format( first_block, last_block ) )

        histogram = session.execute( "SELECT * FROM public.trx_histogram").fetchone()
        session.commit()
        logger.info( "histogram: {}\n".format( histogram ) )

        contexts = session.execute( "SELECT * FROM hive.contexts").fetchone()
        session.commit()
        logger.info( "contexts: {}\n".format( contexts ) )




    def thread_func2():
        count = 0
        while True:
            blocks_range = session.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone()
            session.commit()
            (first_block, last_block) = blocks_range

            if not first_block:
                continue
            session.execute( "SELECT public.update_histogram( {}, {} )".format( first_block, last_block ) )
            session.commit()
    Thread(daemon=True, target=thread_func2).start()

