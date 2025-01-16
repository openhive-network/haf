CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- here we pretend that 50 is the head block
    INSERT INTO hafd.blocks
    VALUES
        ( 50, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hafd.accounts( id, name, block_num )
    VALUES (5, 'initminer', 50)
    ;
END;
$BODY$;

-- all contexts are forehead
CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __alice_stages hafd.application_stages :=
        ARRAY[ ('stage2',100 ,100 )::hafd.application_stage
            , ('stage1',10 ,10 )::hafd.application_stage
            , hafd.live_stage()
            ];
    __alice1_stages hafd.application_stages :=
        ARRAY[ ('stage2',100 ,100 )::hafd.application_stage
            , ('stage1',60 ,10 )::hafd.application_stage
            , hafd.live_stage()
            ];
    __alice2_stages hafd.application_stages :=
        ARRAY[ ('stage2',40 ,100 )::hafd.application_stage
            , ('stage1',30 ,10 )::hafd.application_stage
            , hafd.live_stage()
            ];
BEGIN
    CREATE SCHEMA alice;
    PERFORM hive.app_create_context( 'alice', 'alice', _stages => __alice_stages );
    PERFORM hive.app_create_context( 'alice1', 'alice', _stages => __alice1_stages );
    PERFORM hive.app_create_context( 'alice2', 'alice', _stages => __alice2_stages );

    -- temporary insert stage by force
    UPDATE hafd.contexts
    SET current_block_num = 80;
END;
$BODY$;

CREATE OR REPLACE PROCEDURE alice_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
DECLARE
    __current_stage hafd.application_stage;
    __context TEXT;
BEGIN
    -- alice stage1
    SELECT (stg).context FROM hive.get_current_stage( ARRAY[ 'alice'] ) stg INTO __context;
    SELECT ((stg).stage::hafd.application_stage).* FROM hive.get_current_stage( ARRAY[ 'alice'] ) stg INTO __current_stage;
    ASSERT __context = 'alice' , 'ctx != alice' ;
    ASSERT __current_stage = hafd.live_stage(), 'alice stage != live';

    -- alice1 live
    SELECT (stg).context FROM hive.get_current_stage( ARRAY[ 'alice1'] ) stg INTO __context;
    SELECT ((stg).stage::hafd.application_stage).* FROM hive.get_current_stage( ARRAY[ 'alice1'] ) stg INTO __current_stage;
    ASSERT __context = 'alice1' , 'ctx != alice1' ;
    ASSERT __current_stage = hafd.live_stage(), 'alice1 stage  != live';

    -- alice2 stage2
    SELECT (stg).context FROM hive.get_current_stage( ARRAY[ 'alice2'] ) stg INTO __context;
    SELECT ((stg).stage::hafd.application_stage).* FROM hive.get_current_stage( ARRAY[ 'alice2'] ) stg INTO __current_stage;
    ASSERT __context = 'alice2' , 'ctx != alice2' ;
    ASSERT __current_stage = hafd.live_stage(), 'alice2 stage  != live';


    SELECT ((stg).stage::hafd.application_stage).* FROM hive.get_current_stage( ARRAY[ 'alice', 'alice1', 'alice2' ] ) stg
    WHERE (stg).context = 'alice'  INTO __current_stage;
    ASSERT __current_stage = hafd.live_stage(), 'alice stage != (''stage1'',10 ,10 )';

    SELECT ((stg).stage::hafd.application_stage).* FROM hive.get_current_stage( ARRAY[ 'alice', 'alice1', 'alice2' ] ) stg
    WHERE (stg).context = 'alice1'  INTO __current_stage;
    ASSERT __current_stage = hafd.live_stage(), 'alice1 stage  != live';

    SELECT ((stg).stage::hafd.application_stage).* FROM hive.get_current_stage( ARRAY[ 'alice', 'alice1', 'alice2' ] ) stg
    WHERE (stg).context = 'alice2' INTO __current_stage;
    ASSERT __current_stage = hafd.live_stage(), 'alice2 stage  != (''stage2'',40 ,100 )';
END;
$BODY$;