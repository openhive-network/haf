\ir ../test_tools.sql

CREATE OR REPLACE PROCEDURE haf_admin_test_given()
    LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- here we pretend that 50 is the head block
    PERFORM test.create_blocks(50, 50);

    INSERT INTO hafd.accounts( id, name, block_id )
    VALUES (5, 'initminer', hafd.make_block_id(50, 0))
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

    UPDATE hafd.contexts hc
    SET loop.current_stage = hafd.live_stage()
    WHERE hc.name ='alice_live1';


    UPDATE hafd.contexts hc
    SET loop.current_stage = hafd.live_stage()
    WHERE hc.name ='alice_live2';

    UPDATE hafd.contexts hc
    SET loop.current_stage = hive.stage('stage1',30 ,10 )
    WHERE hc.name ='alice_no_live1';

    UPDATE hafd.contexts hc
    SET loop.current_stage = hive.stage('stage2',40 ,10 )
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