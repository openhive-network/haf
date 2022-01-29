#!/usr/bin/env python3

import sys
import sqlalchemy

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

def create_db_engine(pg_port):
    return sqlalchemy.create_engine(
                "postgresql://alice:test@localhost:{}/psql_tools_test_db".format(pg_port), # this is only example of db
                isolation_level="READ COMMITTED",
                pool_size=1,
                pool_recycle=3600,
                echo=False)

def prepare_application_data( db_connection ):
        # create a new context only if it not already exists
        exist = db_connection.execute( "SELECT hive.app_context_exists( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone();
        if exist[ 0 ] == False:
            db_connection.execute( "SELECT hive.app_create_context( '{}' )".format( APPLICATION_CONTEXT ) )

        # create and register a table
        db_connection.execute( SQL_CREATE_AND_REGISTER_HISTOGRAM_TABLE )

        # create SQL function to do the application's task
        db_connection.execute( SQL_CREATE_UPDATE_HISTOGRAM_FUNCTION )

def main_loop( db_connection ):
    # forever loop
    while True:
        # start a new transaction
        with db_connection.begin():
            # get blocks range
            blocks_range = db_connection.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone()

            print( "Blocks range {}".format( blocks_range ) )
            (first_block, last_block) = blocks_range;
            # if no blocks are fetched then ask for new blocks again
            if not first_block:
                continue;

            (first_block, last_block) = blocks_range;

            # check if massive sync is required
            if ( last_block - first_block ) > 100:
                # Yes, massive sync is required
                # detach context
                db_connection.execute( "SELECT hive.app_context_detach( '{}' )".format( APPLICATION_CONTEXT ) )

                # update massivly the application's table - one commit transaction for whole massive edition
                db_connection.execute( "SELECT public.update_histogram( {}, {} )".format( first_block, last_block ) )

                # attach context and moves it to last synced block
                db_connection.execute( "SELECT hive.app_context_attach( '{}', {} )".format( APPLICATION_CONTEXT, last_block ) )
                continue

            # process the first block in range - one commit after each block
            db_connection.execute( "SELECT public.update_histogram( {}, {} )".format( first_block, last_block ) )

def start_application(pg_port):
    engine = create_db_engine(pg_port)
    with engine.connect() as db_connection:
        prepare_application_data( db_connection )
        main_loop( db_connection )

if __name__ == '__main__':
    try:
        pg_port = sys.argv[1] if (len(sys.argv) > 1) else 5432
        start_application(pg_port)
    except KeyboardInterrupt:
        print( "Break by the user request" )
        pass
