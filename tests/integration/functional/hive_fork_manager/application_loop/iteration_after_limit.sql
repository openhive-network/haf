CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- here we pretend that 50 is the head block
    INSERT INTO hive_data.blocks
    VALUES
           ( 1, '\xBADD11', '\xCAFE11', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
         , ( 50, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive_data.accounts( id, name, block_num )
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
    __alice_stages hive_data.application_stages :=
        ARRAY[ ('stage2',100 ,100 )::hive_data.application_stage
            , ('stage1',10 ,10 )::hive_data.application_stage
            , hive_data.live_stage()
            ];
    __alice1_stages hive_data.application_stages :=
        ARRAY[ ('stage2',100 ,100 )::hive_data.application_stage
            , ('stage1',60 ,10 )::hive_data.application_stage
            , hive_data.live_stage()
            ];
    __alice2_stages hive_data.application_stages :=
        ARRAY[ ('stage2',40 ,100 )::hive_data.application_stage
            , ('stage1',30 ,10 )::hive_data.application_stage
            , hive_data.live_stage()
            ];
BEGIN
    CREATE SCHEMA alice;
    PERFORM hive.app_create_context( 'alice', 'alice', _stages => __alice_stages );
    PERFORM hive.app_create_context( 'alice1', 'alice', _stages => __alice1_stages );
    PERFORM hive.app_create_context( 'alice2', 'alice', _stages => __alice2_stages );
END;
$BODY$;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __range_placeholder hive.blocks_range;
BEGIN
    -- alices context are moved to range (1,10)
    CALL hive.app_next_iteration( ARRAY[ 'alice', 'alice1', 'alice2' ], __range_placeholder );
    RAISE INFO 'blocks range: %', __range_placeholder;
    -- now hb is moved to 100
    INSERT INTO hive_data.blocks
    VALUES
          ( 15, '\xBADD51', '\xCAFE51', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 60, '\xBADD51', '\xCAFE51', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;
    PERFORM hive.set_irreversible( 60 );
END;
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __range_placeholder hive.blocks_range;
BEGIN
    -- Alice start new iteration 10-15(limit)
    CALL hive.app_next_iteration( ARRAY[ 'alice', 'alice1', 'alice2' ], __range_placeholder, _limit => 15 );
    RAISE INFO 'blocks range: %', __range_placeholder;
END;
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __range_placeholder hive.blocks_range;
BEGIN
    CALL hive.app_next_iteration( ARRAY[ 'alice', 'alice1', 'alice2' ], __range_placeholder, _limit => 15 );
    ASSERT __range_placeholder IS NULL;
END;
$BODY$;