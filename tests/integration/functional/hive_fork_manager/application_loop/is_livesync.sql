CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- here we pretend that 50 is the head block
    INSERT INTO hive_data.blocks
    VALUES
        ( 50, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp, 5, '\x4007', E'[]', '\x2157', 'STM65w', 1000, 1000, 1000000, 1000, 1000, 1000, 2000, 2000 )
    ;

    INSERT INTO hive_data.accounts( id, name, block_num )
    VALUES (5, 'initminer', 50)
    ;
END;
$BODY$;


CREATE OR REPLACE PROCEDURE alice_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    CREATE SCHEMA alice;
    PERFORM hive.app_create_context( 'alice_live1', 'alice' );
    PERFORM hive.app_create_context( 'alice_live2', 'alice' );
    PERFORM hive.app_create_context( 'alice_no_live1', 'alice' );
    PERFORM hive.app_create_context( 'alice_no_live2', 'alice' );

    UPDATE hive_data.contexts hc
    SET loop.current_stage = hive_data.live_stage()
    WHERE hc.name ='alice_live1';


    UPDATE hive_data.contexts hc
    SET loop.current_stage = hive_data.live_stage()
    WHERE hc.name ='alice_live2';

    UPDATE hive_data.contexts hc
    SET loop.current_stage = ('stage1',30 ,10 )::hive_data.application_stage
    WHERE hc.name ='alice_no_live1';

    UPDATE hive_data.contexts hc
    SET loop.current_stage = ('stage2',40 ,10 )::hive_data.application_stage
    WHERE hc.name ='alice_no_live1';
END;
$BODY$;


CREATE OR REPLACE PROCEDURE alice_test_then()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT hive.is_livesync( ARRAY[ 'alice_live1', 'alice_live2'] ) = TRUE, 'alice_live1 and alice_live2 are not in live sync';
    ASSERT hive.is_livesync( ARRAY[ 'alice_live2' ] ) = TRUE, 'alice_live2 is not in live sync';
    ASSERT hive.is_livesync( ARRAY[ 'alice_no_live1', 'alice_no_live2' ] ) = FALSE, 'alice_no_live1, alice_no_live2 are in live sync';
    ASSERT hive.is_livesync( ARRAY[ 'alice_live1', 'alice_no_live1', 'alice_no_live2' ] ) = FALSE, 'alice_live1, alice_no_live1, alice_no_live2 are in live sync';
    ASSERT hive.is_livesync( ARRAY[ 'alice_no_live1', 'alice_live1' ] ) = FALSE, 'alice_no_live1, alice_live1 are in live sync';
END;
$BODY$;