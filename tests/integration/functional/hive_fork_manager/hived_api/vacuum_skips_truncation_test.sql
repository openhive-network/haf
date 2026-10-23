CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE EXTENSION IF NOT EXISTS dblink;

    -- enough wide rows to fill trailing pages that a vacuum could truncate once they are deleted
    INSERT INTO hafd.contexts( name, schema, current_block_num, irreversible_block, owner, last_active_at, baseclass_id )
    SELECT 'filler_' || i, repeat( 'x', 1000 ), 0, 0, 'vacuum_filler', NOW(), 'hafd.contexts'::REGCLASS
    FROM generate_series( 1, 500 ) i;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    DELETE FROM hafd.contexts WHERE owner = 'vacuum_filler';
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __size_before BIGINT;
    __started_at TIMESTAMPTZ;
    __vacuum_duration INTERVAL;
BEGIN
    ASSERT ( SELECT reloptions @> ARRAY['vacuum_truncate=false'] FROM pg_class WHERE oid = 'hafd.contexts'::REGCLASS )
        , 'hafd.contexts should have vacuum_truncate disabled';
    ASSERT ( SELECT reloptions @> ARRAY['vacuum_truncate=false'] FROM pg_class WHERE oid = 'hafd.hive_state'::REGCLASS )
        , 'hafd.hive_state should have vacuum_truncate disabled';

    -- as an app does, keep AccessShareLock on hafd.contexts until this transaction ends
    PERFORM COUNT(*) FROM hafd.contexts;
    __size_before := pg_relation_size( 'hafd.contexts' );

    PERFORM dblink_connect( 'vacuum_session', format( 'dbname=%s user=%s port=%s host=%s'
        , current_database(), current_user, current_setting( 'port' )
        , split_part( current_setting( 'unix_socket_directories' ), ',', 1 ) ) );
    __started_at := clock_timestamp();
    PERFORM dblink_exec( 'vacuum_session', 'VACUUM hafd.contexts' );
    __vacuum_duration := clock_timestamp() - __started_at;
    PERFORM dblink_disconnect( 'vacuum_session' );

    -- a truncation attempt blocked by the lock above would retry for PostgreSQL's 5 s VACUUM_TRUNCATE_LOCK_TIMEOUT
    ASSERT __vacuum_duration < INTERVAL '2 seconds'
        , format( 'VACUUM hafd.contexts took %s while another session held AccessShareLock on it', __vacuum_duration );
    ASSERT pg_relation_size( 'hafd.contexts' ) = __size_before
        , 'VACUUM hafd.contexts should not truncate its trailing empty pages';
END;
$BODY$
;
