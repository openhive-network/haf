#!/usr/bin/env python3

import sys
import sqlalchemy
from sqlalchemy import text

APPLICATION_CONTEXT = "trx_histogram_ctx"

SQL_CREATE_AND_REGISTER_HISTOGRAM_TABLE = """
    CREATE TABLE IF NOT EXISTS applications.trx_histogram(
          day DATE
        , trx INT
        , CONSTRAINT pk_trx_histogram PRIMARY KEY( day ) )
    INHERITS( applications.{} )
    """.format( APPLICATION_CONTEXT )

SQL_CREATE_UPDATE_HISTOGRAM_FUNCTION = """
    CREATE OR REPLACE FUNCTION applications.update_histogram( _first_block INT, _last_block INT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
    AS
     $function$
     BEGIN
        INSERT INTO applications.trx_histogram as th( day, trx )
        SELECT
              DATE(hb.created_at) as date
            , COUNT(1) as trx
        FROM applications.blocks_view hb
        JOIN applications.transactions_view ht ON ht.block_num = hb.num
        WHERE hb.num >= _first_block AND hb.num <= _last_block
        GROUP BY DATE(hb.created_at)
        ON CONFLICT ON CONSTRAINT pk_trx_histogram DO UPDATE
        SET
            trx = EXCLUDED.trx + th.trx
        WHERE th.day = EXCLUDED.day;
     END;
     $function$
    """

def create_db_engine(db_name, pg_port):
    return sqlalchemy.create_engine(
                "postgresql://alice:test@localhost:{}/{}".format(pg_port, db_name), # this is only example of db
                isolation_level="READ COMMITTED",
                pool_size=1,
                pool_recycle=3600,
                echo=False)

def prepare_application_data( db_connection ):
        db_connection.execute( "CREATE SCHEMA IF NOT EXISTS applications" )

        # create a new context only if it not already exists
        exist = db_connection.execute( "SELECT hive.app_context_exists( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone();
        if exist[ 0 ] == False:
            db_connection.execute(
                  "SELECT hive.app_create_context("
                  " '{}', _schema => 'applications'"
                  ", _is_forking => TRUE"
                  ", _stages => ARRAY[ ('MASSIVE',2 ,100 )::hive_data.application_stage, hive_data.live_stage()]"
                  ")".format(APPLICATION_CONTEXT)
            )


        # create and register a table
        db_connection.execute( SQL_CREATE_AND_REGISTER_HISTOGRAM_TABLE )

        # create SQL function to do the application's task
        db_connection.execute( SQL_CREATE_UPDATE_HISTOGRAM_FUNCTION )

def main_loop( db_connection ):
    # forever loop
    while True:
        # start a new transaction
        blocks_range = (0,0)
        with db_connection.begin():
            # get blocks range
            iteration_statement = text("CALL hive.app_next_iteration( '{}', :blocks_range )".format(APPLICATION_CONTEXT))
            result = db_connection.execute( iteration_statement, {'blocks_range': blocks_range})

            try:
                import ast
                blocks_range = ast.literal_eval(result.scalar_one())
            except SyntaxError:
                # NULL,NULL was returned
                # if no blocks are fetched then ask for new blocks again
                print("Blocks range (None, None)")
                continue

            print("Blocks range {}".format(blocks_range))
            (first_block, last_block) = blocks_range

            # process the first block in range - one commit after each block
            db_connection.execute( "SELECT applications.update_histogram( {}, {} )".format(first_block, last_block))

def start_application(db_name, pg_port):
    engine = create_db_engine(db_name, pg_port)
    with engine.connect() as db_connection:
        prepare_application_data( db_connection )
        main_loop( db_connection )

if __name__ == '__main__':
    try:
        db_name = sys.argv[1] if (len(sys.argv) > 1) else 'psql_tools_test_db'
        pg_port = sys.argv[2] if (len(sys.argv) > 2) else 5432
        start_application(db_name, pg_port)
    except KeyboardInterrupt:
        print( "Break by the user request" )
        pass
