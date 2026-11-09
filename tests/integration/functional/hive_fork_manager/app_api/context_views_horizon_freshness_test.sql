-- In 'c' mode of hive.set_context_view_horizon_mode, the horizon libhfm caches per snapshot is as fresh as a read of
-- hafd.contexts: an autocommit statement and each READ COMMITTED statement see another session's committed horizon, a
-- REPEATABLE READ transaction keeps the horizon of its snapshot, one statement sees one horizon, and a rolled back
-- subtransaction's horizon is not seen after it. A role which may only read the views sees the committed horizon, and
-- a read of hafd.contexts that fails leaves it the current user. The horizon moves in the `writer` session, and is
-- read in the `reader` session.

-- The current block of the context, as the reader sees it.
CREATE OR REPLACE FUNCTION reader_horizon()
    RETURNS INTEGER
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __block INTEGER;
BEGIN
    SELECT h INTO __block FROM dblink( 'reader', $$ SELECT hive.context_view_horizon_current_block_num( 'context' ) $$ ) AS t( h INTEGER );
    RETURN __block;
END;
$BODY$
;

-- Commits _block as the context's irreversible and current block in the writer session.
CREATE OR REPLACE FUNCTION commit_horizon( _block INTEGER )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
BEGIN
    PERFORM dblink_exec( 'writer', format( 'UPDATE hafd.contexts SET irreversible_block = %1$s, current_block_num = %1$s WHERE name = %2$L', _block, 'context' ) );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION assert_reader_horizon( _expected INTEGER, _state TEXT )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __block INTEGER := reader_horizon();
BEGIN
    ASSERT __block = _expected, format( 'the reader sees block %s, not %s, %s', __block, _expected, _state );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;
    CREATE SCHEMA a;
    PERFORM hive.app_create_context( _name => 'context', _schema => 'a' );

    INSERT INTO hafd.accounts( id, name, block_num ) VALUES ( 5, 'initminer', NULL );
    INSERT INTO hafd.blocks
    SELECT n, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000
    FROM generate_series( 1, 10 ) n;
    UPDATE hafd.contexts SET fork_id = 1, irreversible_block = 1, current_block_num = 1 WHERE name = 'context';

    IF NOT EXISTS ( SELECT 1 FROM pg_roles WHERE rolname = 'context_views_fresh_reader' ) THEN
        CREATE ROLE context_views_fresh_reader;
    END IF;
    GRANT USAGE ON SCHEMA a TO context_views_fresh_reader;
    GRANT SELECT ON ALL TABLES IN SCHEMA a TO context_views_fresh_reader;

    PERFORM hive.set_context_view_horizon_mode( 'c' );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __connection TEXT := format( 'dbname=%s user=%s port=%s host=%s'
        , current_database(), current_user, current_setting( 'port' ), split_part( current_setting( 'unix_socket_directories' ), ',', 1 ) );
    __statement_horizons INTEGER[];
    __blocks BIGINT;
BEGIN
    PERFORM dblink_connect( 'reader', __connection );
    PERFORM dblink_connect( 'writer', __connection );

    PERFORM assert_reader_horizon( 1, 'in autocommit before the horizon moves' );
    PERFORM commit_horizon( 2 );
    PERFORM assert_reader_horizon( 2, 'in autocommit after another session committed block 2' );

    PERFORM dblink_exec( 'reader', 'BEGIN ISOLATION LEVEL READ COMMITTED' );
    PERFORM assert_reader_horizon( 2, 'in a READ COMMITTED transaction' );
    PERFORM commit_horizon( 3 );
    PERFORM assert_reader_horizon( 3, 'in the next statement of a READ COMMITTED transaction after another session committed block 3' );
    PERFORM dblink_exec( 'reader', 'COMMIT' );

    PERFORM dblink_exec( 'reader', 'BEGIN ISOLATION LEVEL REPEATABLE READ' );
    PERFORM assert_reader_horizon( 3, 'in a REPEATABLE READ transaction' );
    PERFORM commit_horizon( 4 );
    PERFORM assert_reader_horizon( 3, 'in a REPEATABLE READ transaction which began before another session committed block 4' );
    PERFORM dblink_exec( 'reader', 'COMMIT' );
    PERFORM assert_reader_horizon( 4, 'after its REPEATABLE READ transaction' );

    -- the horizon moves twice while one statement of about a second reads it a hundred times
    PERFORM dblink_send_query( 'reader', $$
        SELECT array_agg( DISTINCT s.h ) FROM (
            SELECT hive.context_view_horizon_current_block_num( 'context' ) AS h, pg_sleep( 0.01 ) FROM generate_series( 1, 100 )
        ) s $$ );
    PERFORM pg_sleep( 0.2 );
    PERFORM commit_horizon( 5 );
    PERFORM pg_sleep( 0.2 );
    PERFORM commit_horizon( 6 );
    SELECT h INTO __statement_horizons FROM dblink_get_result( 'reader' ) AS t( h INTEGER[] );
    PERFORM * FROM dblink_get_result( 'reader' ) AS t( h INTEGER[] );
    ASSERT __statement_horizons = ARRAY[ 4 ], format( 'one statement saw the horizons %s, not only block 4', __statement_horizons );
    PERFORM assert_reader_horizon( 6, 'in the statement after the one the horizon moved during' );

    -- the reader's own horizon in a subtransaction is not seen once the subtransaction is rolled back
    PERFORM dblink_exec( 'reader', 'BEGIN' );
    PERFORM assert_reader_horizon( 6, 'before a savepoint' );
    PERFORM dblink_exec( 'reader', 'SAVEPOINT own_horizon' );
    PERFORM dblink_exec( 'reader', $$ UPDATE hafd.contexts SET irreversible_block = 7, current_block_num = 7 WHERE name = 'context' $$ );
    PERFORM assert_reader_horizon( 7, 'after its own update in a subtransaction' );
    PERFORM dblink_exec( 'reader', 'ROLLBACK TO SAVEPOINT own_horizon' );
    PERFORM assert_reader_horizon( 6, 'after rolling back to the savepoint before its own update' );
    PERFORM dblink_exec( 'reader', 'RELEASE SAVEPOINT own_horizon' );
    PERFORM assert_reader_horizon( 6, 'after releasing the savepoint it rolled back to' );
    PERFORM dblink_exec( 'reader', 'COMMIT' );

    -- the same with the subtransaction of an exception block, in one statement
    PERFORM dblink_exec( 'reader', $$ DO $do$
        BEGIN
            BEGIN
                UPDATE hafd.contexts SET irreversible_block = 8, current_block_num = 8 WHERE name = 'context';
                IF hive.context_view_horizon_current_block_num( 'context' ) IS DISTINCT FROM 8 THEN
                    RAISE EXCEPTION 'an exception block does not see its own horizon';
                END IF;
                PERFORM 1 / 0;
            EXCEPTION WHEN division_by_zero THEN
                NULL;
            END;
            IF hive.context_view_horizon_current_block_num( 'context' ) IS DISTINCT FROM 6 THEN
                RAISE EXCEPTION 'the horizon of a rolled back exception block is %, not 6', hive.context_view_horizon_current_block_num( 'context' );
            END IF;
        END $do$ $$ );

    -- a role which may only read the views, as an API's, sees the committed horizon
    PERFORM dblink_exec( 'reader', 'SET ROLE context_views_fresh_reader' );
    SELECT b INTO __blocks FROM dblink( 'reader', 'SELECT count(*) FROM a.blocks_view' ) AS t( b BIGINT );
    ASSERT __blocks = 6, format( 'a role reading only the views sees %s blocks, not 6', __blocks );
    PERFORM commit_horizon( 3 );
    SELECT b INTO __blocks FROM dblink( 'reader', 'SELECT count(*) FROM a.blocks_view' ) AS t( b BIGINT );
    ASSERT __blocks = 3, format( 'a role reading only the views sees %s blocks, not 3, after another session committed block 3', __blocks );

    -- a read of hafd.contexts, run as the extension's owner, that fails still leaves the reader its own role
    PERFORM dblink_exec( 'writer', 'BEGIN' );
    PERFORM dblink_exec( 'writer', 'LOCK TABLE hafd.contexts IN ACCESS EXCLUSIVE MODE' );
    PERFORM dblink_exec( 'reader', $$ SET lock_timeout = '200ms' $$ );
    PERFORM dblink_exec( 'reader', $$ DO $do$
        BEGIN
            BEGIN
                PERFORM count(*) FROM a.blocks_view;
                RAISE EXCEPTION 'the read of the horizon did not wait for the lock on hafd.contexts';
            EXCEPTION WHEN lock_not_available THEN
                NULL;
            END;
            IF current_user <> 'context_views_fresh_reader' THEN
                RAISE EXCEPTION 'after a failed read of the horizon the current user is %', current_user;
            END IF;
        END $do$ $$ );
    PERFORM dblink_exec( 'writer', 'ROLLBACK' );
    ASSERT ( SELECT u FROM dblink( 'reader', 'SELECT current_user::TEXT' ) AS t( u TEXT ) ) = 'context_views_fresh_reader'
        , 'after a failed read of the horizon the reader is not its own role';
    SELECT b INTO __blocks FROM dblink( 'reader', 'SELECT count(*) FROM a.blocks_view' ) AS t( b BIGINT );
    ASSERT __blocks = 3, format( 'once hafd.contexts is unlocked, a role reading only the views sees %s blocks, not 3', __blocks );

    PERFORM dblink_disconnect( 'reader' );
    PERFORM dblink_disconnect( 'writer' );
END;
$BODY$
;
