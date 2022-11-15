DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    raise notice 'MTTK hive.irreversible_data=%',    (        SELECT json_agg(t)        FROM (                SELECT *                FROM hive.irreversible_data            ) t    );
    INSERT INTO hive.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w' )
    ;
    raise notice 'MTTK hive.irreversible_data=%',    (        SELECT json_agg(t)        FROM (                SELECT *                FROM hive.irreversible_data            ) t    );
    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
         , (6, 'alice', 1)
         , (7, 'bob', 1)
    ;
    raise notice 'MTTK hive.irreversible_data=%',    (        SELECT json_agg(t)        FROM (                SELECT *                FROM hive.irreversible_data            ) t    );
    PERFORM hive.end_massive_sync( 1 );
    raise notice 'MTTK hive.irreversible_data=%',    (        SELECT json_agg(t)        FROM (                SELECT *                FROM hive.irreversible_data            ) t    );
    PERFORM hive.push_block(
         ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 6, '\x4007', E'[]', '\x2157', 'STM65w' )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    raise notice 'MTTK hive.irreversible_data=%',    (        SELECT json_agg(t)        FROM (                SELECT *                FROM hive.irreversible_data            ) t    );

    PERFORM hive.push_block(
         ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 7, '\x4007', E'[]', '\x2157', 'STM65w' )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );

    raise notice 'MTTK hive.irreversible_data=%',    (        SELECT json_agg(t)        FROM (                SELECT *                FROM hive.irreversible_data            ) t    );
    PERFORM hive.push_block(
         ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 8, '\x4007', E'[]', '\x2157', 'STM65w' )
        , NULL
        , NULL
        , NULL
        , NULL
        , NULL
    );
    raise notice 'MTTK hive.irreversible_data=%',    (        SELECT json_agg(t)        FROM (                SELECT *                FROM hive.irreversible_data            ) t    );

    PERFORM hive.app_create_context( 'context' );
    raise notice 'MTTK hive.irreversible_data=%',    (        SELECT json_agg(t)        FROM (                SELECT *                FROM hive.irreversible_data            ) t    );
    CREATE SCHEMA A;
    raise notice 'MTTK hive.irreversible_data=%',    (        SELECT json_agg(t)        FROM (                SELECT *                FROM hive.irreversible_data            ) t    );
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context );
    raise notice 'MTTK hive.irreversible_data=%',    (        SELECT json_agg(t)        FROM (                SELECT *                FROM hive.irreversible_data            ) t    );

    PERFORM hive.app_next_block( 'context' ); -- NEW_BLOCK event block 1
    raise notice 'MTTK hive.irreversible_data=%',    (        SELECT json_agg(t)        FROM (                SELECT *                FROM hive.irreversible_data            ) t    );
    PERFORM hive.app_next_block( 'context' ); -- NEW_BLOCK event block 2
    raise notice 'MTTK hive.irreversible_data=%',    (        SELECT json_agg(t)        FROM (                SELECT *                FROM hive.irreversible_data            ) t    );
    PERFORM hive.app_next_block( 'context' ); -- NEW_BLOCK event block 3
    raise notice 'MTTK hive.irreversible_data=%',    (        SELECT json_agg(t)        FROM (                SELECT *                FROM hive.irreversible_data            ) t    );
    PERFORM hive.app_next_block( 'context' ); -- NEW_BLOCK event block 4
    raise notice 'MTTK hive.irreversible_data=%',    (        SELECT json_agg(t)        FROM (                SELECT *                FROM hive.irreversible_data            ) t    );
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __result INT;
BEGIN
    raise notice 'MTTK hive.irreversible_data=%',    (        SELECT json_agg(t)        FROM (                SELECT *                FROM hive.irreversible_data            ) t    );

    PERFORM hive.set_irreversible( 3 );

    raise notice 'MTTK hive.irreversible_data=%',    (        SELECT json_agg(t)        FROM (                SELECT *                FROM hive.irreversible_data            ) t    );

END
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM hive.events_queue ) = 3, 'Wrong number of events';
    ASSERT ( SELECT hid.consistent_block FROM hive.irreversible_data hid ) = 3 , 'Wrong consisten irreversible block';
    ASSERT EXISTS ( SELECT * FROM hive.events_queue WHERE event = 'NEW_BLOCK' AND block_num=4 ), 'No NEW_BLOCK event 4';
    ASSERT EXISTS ( SELECT * FROM hive.events_queue WHERE event = 'NEW_IRREVERSIBLE' AND block_num=3 ), 'No NEW_IRREVERSIBLE event';
END;
$BODY$
;




