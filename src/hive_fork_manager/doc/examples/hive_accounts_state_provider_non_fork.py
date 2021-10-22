#!/usr/bin/env python3

import sqlalchemy

APPLICATION_CONTEXT = "accounts"

def create_db_engine():
    return sqlalchemy.create_engine(
                "postgresql://alice:test@localhost:5432/psql_tools_test_db", # this is only example of db
                isolation_level="READ COMMITTED",
                pool_size=1,
                pool_recycle=3600,
                echo=False)

def prepare_application_data( db_connection ):
        # create a new context only if it not already exists
        exist = db_connection.execute( "SELECT hive.app_context_exists( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone();
        if exist[ 0 ] == False:
            db_connection.execute( "SELECT hive.app_create_context( '{}' )".format( APPLICATION_CONTEXT ) )

        # import accounts state provider
        db_connection.execute( "SELECT hive.app_state_provider_import( 'ACCOUNTS', '{}' )".format( APPLICATION_CONTEXT ) );

def main_loop( db_connection ):
    # forever loop
    while True:
        # start a new transaction
        with db_connection.begin():
            # get blocks range
            blocks_range = db_connection.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone()
            accounts = db_connection.execute( "SELECT * FROM hive.{}_accounts ORDER BY id DESC LIMIT 1".format( APPLICATION_CONTEXT ) ).fetchall()

            print( "Blocks range {}".format( blocks_range ) )
            print( "Accounts {}".format( accounts ) )
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
                db_connection.execute( "SELECT hive.app_state_providers_update( {}, {}, '{}' )".format( first_block, last_block, APPLICATION_CONTEXT ) )

                # attach context and moves it to last synced block
                db_connection.execute( "SELECT hive.app_context_attach( '{}', {} )".format( APPLICATION_CONTEXT, last_block ) )
                continue

            # process the first block in range - one commit after each block
            db_connection.execute( "SELECT hive.app_state_providers_update( {}, {}, '{}' )".format( first_block, first_block, APPLICATION_CONTEXT ) )

def start_application():
    engine = create_db_engine()
    with engine.connect() as db_connection:
        prepare_application_data( db_connection )
        main_loop( db_connection )

if __name__ == '__main__':
    try:
        start_application()
    except KeyboardInterrupt:
        print( "Break by the user request" )
        pass