CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- here we pretend that 50 is the head block
    INSERT INTO hafd.blocks
    VALUES
           ( 1, '\xBADD11', '\xCAFE11', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 100, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 101, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 102, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 200, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 201, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 202, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 300, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 400, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 500, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (1, 'initminer', 1)
    ;

    PERFORM hive.set_irreversible( 500 );
END;
$BODY$;


CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __alice_stages hafd.application_stages :=
        ARRAY[ hive.stage('stage2',100 ,100 )
            , hive.stage('stage1',10 ,10 )
            , hafd.live_stage()
            ];
    __alice1_stages hafd.application_stages :=
        ARRAY[ hive.stage('stage2',100 ,100 )
            , hive.stage('stage1',60 ,10 )
            , hafd.live_stage()
            ];
    __alice2_stages hafd.application_stages :=
        ARRAY[ hive.stage('stage2',40 ,100 )
            , hive.stage('stage1',30 ,10 )
            , hafd.live_stage()
            ];
    __range_placeholder hive.blocks_range;
BEGIN
    CREATE SCHEMA alice;
    PERFORM hive.app_create_context( 'alice', 'alice', _stages => __alice_stages );
    PERFORM hive.app_create_context( 'alice1', 'alice', _stages => __alice1_stages );
    PERFORM hive.app_create_context( 'alice2', 'alice', _stages => __alice2_stages );

    --first iteration
    -- stages are analyzes and max batch is set to 100
    CALL hive.app_next_iteration( ARRAY[ 'alice', 'alice1', 'alice2' ], __range_placeholder );
    -- we are at <1-101> block
END;
$BODY$;


CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __range_placeholder hive.blocks_range;
BEGIN
    UPDATE hafd.contexts
    SET last_active_at = '0001-01-01 00:00:00'::TIMESTAMP;

    -- Alice start new iteration <102-202>
    CALL hive.app_next_iteration( ARRAY[ 'alice', 'alice1', 'alice2' ], __range_placeholder );

    ASSERT ( SELECT last_active_at FROM hafd.contexts WHERE name = 'alice' ) != '0001-01-01 00:00:00'::TIMESTAMP, 'alice time not updated';
    ASSERT ( SELECT last_active_at FROM hafd.contexts WHERE name = 'alice1' ) != '0001-01-01 00:00:00'::TIMESTAMP, 'alice1 time not updated';
    ASSERT ( SELECT last_active_at FROM hafd.contexts WHERE name = 'alice2' ) != '0001-01-01 00:00:00'::TIMESTAMP, 'alice2 time not updated';
END;
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __current_batch_end INTEGER;
    __current_block_num INTEGER;
BEGIN
    -- check if contexts are correctly updated
    -- alice stage1
    SELECT (hc.loop).current_batch_end, hc.current_block_num
    FROM hafd.contexts hc WHERE hc.name = 'alice'
    INTO __current_batch_end, __current_block_num;
    ASSERT __current_block_num = 200, 'Wrong Alice current block !=102';
    ASSERT __current_batch_end = 200, 'Wrong Alice end of range !=202'; --not 51 because head block=50 limits range
    ASSERT hive.app_context_is_attached( 'alice' ) = FALSE, 'Context alice is attached';

    SELECT (hc.loop).current_batch_end, hc.current_block_num
    FROM hafd.contexts hc WHERE hc.name = 'alice1'
    INTO __current_batch_end, __current_block_num;
    ASSERT __current_block_num = 200, 'Wrong Alice1 current block !=102';
    ASSERT __current_batch_end = 200, 'Wrong Alice1 end of range !=202'; --not 51 because head block=50 limits range
    ASSERT hive.app_context_is_attached( 'alice1' ) = FALSE, 'Context alice1 is attached';

    SELECT (hc.loop).current_batch_end, hc.current_block_num
    FROM hafd.contexts hc WHERE hc.name = 'alice2'
    INTO __current_batch_end, __current_block_num;
    ASSERT __current_block_num = 200, 'Wrong Alice2 current block !=102';
    ASSERT __current_batch_end = 200, 'Wrong Alice2 end of range !=202'; --not 51 because head block=50 limits range
    ASSERT hive.app_context_is_attached( 'alice2' ) = FALSE, 'Context alice1 is attached';
END;
$BODY$;