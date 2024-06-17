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
BEGIN
    CREATE SCHEMA alice;
    PERFORM hive.app_create_context( 'alice', 'alice', _stages => __alice_stages );
    PERFORM hive.app_create_context( 'alice1', 'alice', _stages => __alice1_stages );
    PERFORM hive.app_create_context( 'alice2', 'alice', _stages => __alice2_stages );
END;
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_when()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __range_placeholder hive.blocks_range;
BEGIN
    CALL hive.app_next_iteration( ARRAY[ 'alice', 'alice1', 'alice2' ], __range_placeholder );
END;
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __batch_size INTEGER;
BEGIN
    -- check if contexts are correctly updated
    -- alice stage1
    SELECT (hc.loop).size_of_blocks_batch  FROM hive.contexts hc WHERE hc.name = 'alice' INTO __batch_size;
    ASSERT __batch_size = 10, 'alice batch size != 10';

    SELECT (hc.loop).size_of_blocks_batch  FROM hive.contexts hc WHERE hc.name = 'alice1' INTO __batch_size;
    ASSERT __batch_size = 10, 'alice1 batch size != 10';

    SELECT (hc.loop).size_of_blocks_batch  FROM hive.contexts hc WHERE hc.name = 'alice2' INTO __batch_size;
    ASSERT __batch_size = 10, 'alice2 batch size != 10';

END;
$BODY$;