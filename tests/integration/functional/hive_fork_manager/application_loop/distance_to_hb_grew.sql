CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- here we pretend that 50 is the head block
    INSERT INTO hive.blocks
    VALUES
           ( 1, '\xBADD11', '\xCAFE11', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 50, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive.accounts( id, name, block_num )
    VALUES (1, 'initminer', 1)
    ;

    PERFORM hive.set_irreversible( 50 );
END;
$BODY$;


CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __alice_stages hive.application_stages :=
        ARRAY[ ('stage2',100 ,100 )::hive.application_stage
            , ('stage1',10 ,10 )::hive.application_stage
            , hive.live_stage()
            ];
    __alice1_stages hive.application_stages :=
        ARRAY[ ('stage2',100 ,100 )::hive.application_stage
            , ('stage1',60 ,10 )::hive.application_stage
            , hive.live_stage()
            ];
    __alice2_stages hive.application_stages :=
        ARRAY[ ('stage2',40 ,100 )::hive.application_stage
            , ('stage1',30 ,10 )::hive.application_stage
            , hive.live_stage()
            ];
    __range_placeholder hive.blocks_range;
BEGIN
    CREATE SCHEMA alice;
    PERFORM hive.app_create_context( 'alice', 'alice', _stages => __alice_stages );
    PERFORM hive.app_create_context( 'alice1', 'alice', _stages => __alice1_stages );
    PERFORM hive.app_create_context( 'alice2', 'alice', _stages => __alice2_stages );

    -- lets update stages to distance of 50 blocks
    CALL hive.app_next_iteration( ARRAY[ 'alice', 'alice1', 'alice2' ], __range_placeholder );
END;
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- now hb is moved to 200, it pretends situation when head block moves quicker than application
    -- or application was stopped for a while
    INSERT INTO hive.blocks
    VALUES
          ( 51, '\xBADD11', '\xCAFE11', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 400, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;
    PERFORM hive.set_irreversible( 400 );
END;
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
        __range_placeholder hive.blocks_range;
BEGIN
    -- Alice start new iteration, but distance to hb has grown form 50 to 150
    -- stages have to be recalculated
    CALL hive.app_next_iteration( ARRAY[ 'alice', 'alice1', 'alice2' ], __range_placeholder );
END;
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __current_batch_end INTEGER;
    __current_block_num INTEGER;
    __current_stage_name hive.stage_name;
BEGIN
    -- check if contexts are correctly updated
    -- alice stage1
    SELECT (hc.loop).current_batch_end, hc.current_block_num, (hc.loop).current_stage.name
    FROM hive.contexts hc WHERE hc.name = 'alice'
    INTO __current_batch_end, __current_block_num, __current_stage_name;
    ASSERT __current_stage_name = 'stage2', 'Alice got wrong stage != stage2';
    ASSERT __current_block_num = 150, 'Wrong Alice current block !=150';
    ASSERT __current_batch_end = 150, 'Wrong Alice end of range !=150';

    SELECT (hc.loop).current_batch_end, hc.current_block_num, (hc.loop).current_stage.name
    FROM hive.contexts hc WHERE hc.name = 'alice1'
    INTO __current_batch_end, __current_block_num, __current_stage_name;
    ASSERT __current_stage_name = 'stage2', 'Alice1 got wrong stage != stage2';
    ASSERT __current_block_num = 150, 'Wrong Alice1 current block !=150';
    ASSERT __current_batch_end = 150, 'Wrong Alice1 end of range !=150';

    SELECT (hc.loop).current_batch_end, hc.current_block_num, (hc.loop).current_stage.name
    FROM hive.contexts hc WHERE hc.name = 'alice2'
    INTO __current_batch_end, __current_block_num, __current_stage_name;
    ASSERT __current_stage_name = 'stage2', 'Alice2 got wrong stage != stage2';
    ASSERT __current_block_num = 150, 'Wrong Alice2 current block !=150';
    ASSERT __current_batch_end = 150, 'Wrong Alice2 end of range !=150';
END;
$BODY$;