-- A context created without stages and driven by hive.app_next_iteration gets the default stages
-- and processes blocks in massive batches. Before, it stayed in an undefined stage with a batch of
-- one block, and every iteration attached it, delivered one block and detached it again.

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __account hafd.accounts%ROWTYPE;
    __block INTEGER;
BEGIN
    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name => 'context', _schema => 'a' );
    CREATE TABLE A.table1( id INTEGER ) INHERITS( a.context );
    CREATE TABLE A.delivered( first_block INTEGER, last_block INTEGER );

    __account = ( 5, 'initminer', 1 );
    PERFORM hive.push_block(
         ( 1, '\xBADD0001', '\xCAFE10', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , ARRAY[ __account ]
        , NULL
        , NULL
    );

    FOR __block IN 2 .. 300 LOOP
        PERFORM hive.push_block(
             ( __block, ('\xBADD' || lpad( __block::TEXT, 4, '0' ))::bytea, '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
            , NULL, NULL, NULL, NULL, NULL, NULL
        );
    END LOOP;
    PERFORM hive.set_irreversible( 300 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
    __iteration INTEGER;
BEGIN
    PERFORM test.install_mock_hive_get_estimated_hive_head_block();
    PERFORM test.set_head_block_num( 300 );

    -- one block per iteration would need 300 iterations
    FOR __iteration IN 1 .. 20 LOOP
        CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks );
        IF __blocks IS NOT NULL THEN
            INSERT INTO A.delivered VALUES( __blocks.first_block, __blocks.last_block );
        END IF;
        EXIT WHEN ( SELECT current_block_num FROM hafd.contexts WHERE name = 'context' ) >= 300;
    END LOOP;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __attach_events INTEGER;
    __missing INTEGER;
    __duplicated INTEGER;
BEGIN
    ASSERT ( SELECT stages FROM hafd.contexts WHERE name = 'context' ) = hive.default_stages(), 'Default stages were not set';
    ASSERT ( SELECT MAX( last_block - first_block + 1 ) FROM A.delivered ) > 1, 'Context processed blocks one by one';
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name = 'context' ) = 300, 'Context did not reach the head block';

    SELECT COUNT(*) INTO __attach_events
    FROM hafd.contexts_log log
    WHERE log.context_name = 'context' AND log.event_type IN ( 'ATTACHED', 'DETACHED' );
    ASSERT __attach_events <= 3, FORMAT( 'Context was attached and detached %s times', __attach_events );

    SELECT COUNT(*) INTO __missing
    FROM generate_series( 1, 300 ) AS b( num )
    WHERE NOT EXISTS ( SELECT 1 FROM A.delivered d WHERE b.num BETWEEN d.first_block AND d.last_block );
    ASSERT __missing = 0, FORMAT( '%s block(s) were never delivered to the application', __missing );

    SELECT COUNT(*) INTO __duplicated
    FROM generate_series( 1, 300 ) AS b( num )
    WHERE ( SELECT COUNT(*) FROM A.delivered d WHERE b.num BETWEEN d.first_block AND d.last_block ) > 1;
    ASSERT __duplicated = 0, FORMAT( '%s block(s) were delivered more than once', __duplicated );

    -- explicit stages replace the default ones and are validated
    PERFORM hive.app_context_set_stages( ARRAY[ 'context' ], ARRAY[ hive.stage( 'massive', 50, 500 ), hafd.live_stage() ] );
    ASSERT ( SELECT (stages[1]).name FROM hafd.contexts WHERE name = 'context' ) = 'massive', 'Stages were not replaced';

    BEGIN
        PERFORM hive.app_context_set_stages( ARRAY[ 'context' ], ARRAY[ hive.stage( 'massive', 50, 500 ) ] );
        ASSERT FALSE, 'No expected exception for stages without the live stage';
    EXCEPTION WHEN raise_exception THEN
    END;

    BEGIN
        PERFORM hive.app_context_set_stages( ARRAY[ 'not_existed_context' ], hive.default_stages() );
        ASSERT FALSE, 'No expected exception for a context which does not exist';
    EXCEPTION WHEN raise_exception THEN
    END;
END;
$BODY$
;
