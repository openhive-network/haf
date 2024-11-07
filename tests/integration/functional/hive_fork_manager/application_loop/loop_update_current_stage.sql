CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- here we pretend that 50 is the head block
    INSERT INTO hafd.blocks
    VALUES
          ( 1, '\xBADD11', '\xCAFE11', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
        , ( 50, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 1, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
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
    __alice_stages hafd.application_stages :=
        ARRAY[ hafd.custom_stage('stage2',100 ,100 )
            , hafd.custom_stage('stage1',10 ,10 )
            , hafd.live_stage()
            ];
    __alice1_stages hafd.application_stages :=
        ARRAY[ hafd.custom_stage('stage2',100 ,100 )
            , hafd.custom_stage('stage1',60 ,10 )
            , hafd.live_stage()
            ];
    __alice2_stages hafd.application_stages :=
        ARRAY[ hafd.custom_stage('stage2',40 ,100 )
            , hafd.custom_stage('stage1',30 ,10 )
            , hafd.live_stage()
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
    UPDATE hafd.contexts
    SET last_active_at = '0001-01-01 00:00:00'::TIMESTAMP;

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
    __current_stage hafd.application_stage;
BEGIN
    -- check if contexts are correctly updated
    -- alice stage1
    SELECT ((hc.loop).current_stage).*  FROM hafd.contexts hc WHERE hc.name = 'alice' INTO __current_stage;
    ASSERT __current_stage = hafd.custom_stage('stage1',10 ,10 ), 'alice stage != (''stage1'',10 ,10 )';
    ASSERT hive.get_current_stage_name( 'alice' ) = 'stage1', 'Wrong name of Alice stage !=stage1';
    ASSERT hive.app_context_is_attached( 'alice' ) = FALSE, 'Context alice is attached';

    -- alice1 live
    SELECT ((hc.loop).current_stage).* FROM hafd.contexts hc WHERE hc.name = 'alice1' INTO __current_stage;
    ASSERT __current_stage = hafd.live_stage(), 'alice1 stage  != live';
    ASSERT hive.get_current_stage_name( 'alice1' ) = 'live', 'Wrong name of Alice1 stage !=live';
    ASSERT hive.app_context_is_attached( 'alice1' ) = FALSE, 'Context alice1 is attached';

    -- alice2 stage2
    SELECT ((hc.loop).current_stage).* FROM hafd.contexts hc WHERE hc.name = 'alice2' INTO __current_stage;
    ASSERT __current_stage = hafd.custom_stage('stage2',40 ,100 ), 'alice2 stage  != (''stage2'',40 ,100 )';
    ASSERT hive.get_current_stage_name( 'alice2' ) = 'stage2', 'Wrong name of Alice2 stage !=stage2';
    ASSERT hive.app_context_is_attached( 'alice2' ) = FALSE, 'Context alice2 is attached';
END;
$BODY$;