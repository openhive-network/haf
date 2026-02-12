-- Load test utilities
\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- Create blocks 1-4
    PERFORM test.create_blocks(1, 4);

    -- Create accounts
    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(1, 0))
         , (6, 'alice', hafd.make_block_id(1, 0));

    PERFORM hive.end_massive_sync(4);

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a'  );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __result hive.blocks_range;
BEGIN
    SELECT * INTO __result FROM hive.app_next_block( 'context' );
    ASSERT __result = (1,4), 'Wrong blocks range instead of (1,4)';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name = 'context' ) = 4, 'Internally irreversible_block has changed';

    SELECT * INTO __result FROM hive.app_next_block( 'context' );
    ASSERT __result = (2,4), 'Wrong blocks range instead of (2,4)';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name = 'context' ) = 4, 'Internally irreversible_block has changed';

    SELECT * INTO __result FROM hive.app_next_block( 'context' );
    ASSERT __result = (3,4), 'Wrong blocks range instead of (3,4)';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name = 'context' ) = 4, 'Internally irreversible_block has changed';

    SELECT * INTO __result FROM hive.app_next_block( 'context' );
    ASSERT __result = (4,4), 'Wrong blocks range instead of (4,4)';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name = 'context' ) = 4, 'Internally irreversible_block has changed';

    SELECT * INTO __result FROM hive.app_next_block( 'context' );
    ASSERT __result IS NULL, 'NUll was expected after end on irreversible blocks';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name = 'context' ) = 4, 'Internally irreversible_block has changed';
END
$BODY$
;




