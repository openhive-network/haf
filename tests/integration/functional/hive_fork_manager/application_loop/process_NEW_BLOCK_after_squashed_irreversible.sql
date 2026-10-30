CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __context_stages hafd.application_stages := ARRAY[ hive.stage('stage1',2 ,3 ), hafd.live_stage() ];
    __blocks hive.blocks_range;
BEGIN
    INSERT INTO hafd.blocks
    VALUES ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 1)
    ;

    PERFORM hive.end_massive_sync( 1 );
    PERFORM test.install_mock_hive_get_estimated_hive_head_block();
    PERFORM test.set_head_block_num(3);

    PERFORM hive.push_block(
         ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL, NULL, NULL, NULL, NULL, NULL
    );

    PERFORM hive.push_block(
         ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL, NULL, NULL, NULL, NULL, NULL
    );

    CREATE SCHEMA A;
    PERFORM hive.app_create_context( _name =>  'context', _schema => 'a', _stages => __context_stages  );
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( a.context );

    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks ); -- block 1
    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks ); -- NEW_BLOCK event block 2
    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks ); -- NEW_BLOCK event block 3
    INSERT INTO A.table1(id) VALUES( 3 );
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
    AS
$BODY$
DECLARE
    __blocks hive.blocks_range;
    __iterations INT := 0;
BEGIN
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name='context' ) = 3, 'Context did not reach block 3';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name='context' ) < 3, 'Context irreversible block is not stale';

    -- hived makes 3..5 irreversible before the context consumes the NEW_BLOCK events of 4 and 5
    PERFORM hive.push_block(
         ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL, NULL, NULL, NULL, NULL, NULL
    );
    PERFORM hive.push_block(
         ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL, NULL, NULL, NULL, NULL, NULL
    );
    PERFORM hive.set_irreversible( 5 );
    PERFORM hive.push_block(
         ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:25-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , NULL, NULL, NULL, NULL, NULL, NULL
    );
    ASSERT ( SELECT consistent_block FROM hafd.hive_state ) = 5, 'Wrong consistent block';

    -- the state left by the squash: the context is past the NEW_BLOCK events of 4 and 5 and the
    -- NEW_IRREVERSIBLE event of 5, its stored irreversible block still from before
    UPDATE hafd.contexts
    SET events_id = ( SELECT id FROM hafd.events_queue WHERE event = 'NEW_IRREVERSIBLE' AND block_num = 5 )
    WHERE name = 'context';
    DELETE FROM hafd.events_queue WHERE event = 'NEW_BLOCK' AND block_num IN ( 4, 5 );

    PERFORM test.set_head_block_num(6);

    CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks );
    ASSERT __blocks IS NOT NULL, 'No range returned for the squashed irreversible blocks';
    ASSERT __blocks.first_block = 4, 'Wrong first block of the irreversible range ' || __blocks.first_block;
    ASSERT __blocks.last_block BETWEEN 4 AND 5, 'Wrong last block of the irreversible range ' || __blocks.last_block;
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name='context' ) = 5, 'Stored irreversible block not refreshed';

    WHILE ( SELECT current_block_num FROM hafd.contexts WHERE name='context' ) < 6 LOOP
        __iterations := __iterations + 1;
        ASSERT __iterations <= 5, 'Context did not reach block 6';
        CALL hive.app_next_iteration( ARRAY[ 'context' ], __blocks );
        ASSERT __blocks IS NULL OR __blocks.first_block <= __blocks.last_block, 'Context stopped before block 6: ' || __blocks::TEXT;
    END LOOP;
    ASSERT __blocks = ( 6, 6 )::hive.blocks_range, 'Block 6 not delivered from its NEW_BLOCK event: ' || __blocks::TEXT;
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT current_block_num FROM hafd.contexts WHERE name='context' ) = 6, 'Wrong current block num';
    ASSERT ( SELECT irreversible_block FROM hafd.contexts WHERE name='context' ) = 5, 'Wrong irreversible';
    ASSERT hive.app_context_is_attached( 'context' ) = TRUE, 'Context context is not attached';
    ASSERT NOT EXISTS ( SELECT * FROM hafd.shadow_a_table1 ), 'Shadow table still holds rows of irreversible block 3';
END
$BODY$
;
