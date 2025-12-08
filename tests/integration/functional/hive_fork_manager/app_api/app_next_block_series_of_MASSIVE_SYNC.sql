-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Create blocks 1-6
    PERFORM test.create_blocks(1, 6);

    -- Create initminer account
    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1);

    PERFORM hive.end_massive_sync( 1 );
    PERFORM hive.end_massive_sync( 2 );
    PERFORM hive.end_massive_sync( 3 );
    PERFORM hive.end_massive_sync( 4 );
    PERFORM hive.end_massive_sync( 5 );
    PERFORM hive.end_massive_sync( 6 );

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
__blocks hive.blocks_range;
BEGIN
    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- MASSIVE_SYNC(1)
    ASSERT __blocks IS NOT NULL, 'Null returned for MASSIVE_SYNC_1';
    RAISE NOTICE 'Received blocks=%', __blocks;
    ASSERT __blocks.first_block = 1, 'Incorrect first block 1';
    ASSERT __blocks.last_block = 6, 'Incorrect last range 6';

    SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; -- MASSIVE_SYNC(2)
    ASSERT __blocks IS NOT NULL, 'Null returned for MASSIVE_SYNC_2';
    RAISE NOTICE 'Received blocks=%', __blocks;
    ASSERT __blocks.first_block = 2, 'Incorrect first block 2';
    ASSERT __blocks.last_block = 6, 'Incorrect last range 6';
END
$BODY$
;




