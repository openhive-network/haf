
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
        __result hive.blocks_range;
BEGIN
    INSERT INTO hive.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
         , (7, 'bob', 1)
    ;

    PERFORM hive.end_massive_sync( 1 );

    PERFORM hive.push_block(
         ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 6, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    PERFORM hive.push_block(
         ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 7, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( 'context1', 'a' );
    PERFORM hive.app_create_context( 'context2', 'a' );

    SELECT * FROM hive.app_next_block( ARRAY[ 'context1', 'context2' ] ) INTO __result; --(1,2)
    RAISE INFO 'app_next_block %', __result;
    SELECT * FROM hive.app_next_block( ARRAY[ 'context1', 'context2' ] ) INTO __result; --(2,2)
    RAISE INFO 'app_next_block %', __result;
    SELECT * FROM hive.app_next_block( ARRAY[ 'context1', 'context2' ] ) INTO __result; -- (3,3)
    RAISE INFO 'app_next_block %', __result;

    PERFORM hive.back_from_fork( 2 );

    PERFORM hive.push_block(
            ( 3, '\xBADD31', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 7, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );


    PERFORM hive.push_block(
            ( 4, '\xBADD41', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 8, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    SELECT * FROM hive.app_next_block( 'context2' ) INTO __result;
    RAISE INFO 'app_next_block ctx2 %', __result; -- BFF event

    SELECT * FROM hive.app_next_block( 'context2' ) INTO __result;
    RAISE INFO 'app_next_block ctx2 %', __result; -- (3,3) from a  new fork

    SELECT * FROM hive.app_next_block( 'context2' ) INTO __result;
    RAISE INFO 'app_next_block ctx2 %', __result; -- (4,4) from a  new fork

    -- context1 stay on block 3 before a fork event
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __result INT;
BEGIN
    ASSERT ( SELECT hash FROM hive.context2_blocks_view WHERE num = 3 ) = '\xBADD31', 'Wrong block 3 visible from context2 before set irreversible';
    ASSERT ( SELECT hash FROM hive.context1_blocks_view WHERE num = 3 ) = '\xBADD30', 'Wrong block 3 visible from context1 before set irreversible';

    PERFORM hive.set_irreversible( 3 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- context2 must see block 3 from 2 fork
    ASSERT ( SELECT hash FROM hive.context2_blocks_view WHERE num = 3 ) = '\xBADD31', 'Wrong block 3 visible from context2';

    -- context1 must see block 3 from 1 fork
    ASSERT ( SELECT hash FROM hive.context1_blocks_view WHERE num = 3 ) = '\xBADD30', 'Wrong block 3 visible from context1';
END;
$BODY$
;




