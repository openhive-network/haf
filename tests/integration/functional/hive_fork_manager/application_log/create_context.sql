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
    PERFORM hive.set_irreversible( 50 );
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
BEGIN
    CREATE SCHEMA alice;
    PERFORM hive.app_create_context( _name => 'alice',  _schema => 'alice', _stages => __alice_stages );
    PERFORM hive.app_create_context( _name => 'alice1', _schema => 'alice' );
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
    ASSERT EXISTS( SELECT 1 FROM hafd.contexts_log WHERE id = 1 AND context_name = 'alice' ), 'No entry for alice';
    ASSERT ( SELECT event_type FROM hafd.contexts_log WHERE id = 1 ) = 'CREATED', 'Wrong alice reason';
    ASSERT ( SELECT application_stage FROM hafd.contexts_log WHERE id = 1 ) IS NULL, 'Wrong alice stage';
    ASSERT ( SELECT application_block FROM hafd.contexts_log WHERE id = 1 ) = 0 , 'Wrong alice app block';
    ASSERT ( SELECT application_fork FROM hafd.contexts_log WHERE id = 1 ) = 1 , 'Wrong alice app fork';
    ASSERT ( SELECT head_fork_id FROM hafd.contexts_log WHERE id = 1 ) = 1 , 'Wrong alice head fork';
    ASSERT ( SELECT head_block FROM hafd.contexts_log WHERE id = 1 ) = 50 , 'Wrong alice head block';

    ASSERT EXISTS( SELECT 1 FROM hafd.contexts_log WHERE id = 2 AND context_name = 'alice1' ), 'No entry for alice1';
    ASSERT ( SELECT event_type FROM hafd.contexts_log WHERE id = 2 ) = 'CREATED', 'Wrong alice1 reason';
    ASSERT ( SELECT application_stage FROM hafd.contexts_log WHERE id = 2 ) IS NULL, 'Wrong alice1 stage';
    ASSERT ( SELECT application_block FROM hafd.contexts_log WHERE id = 2 ) = 0 , 'Wrong alice1 app block';
    ASSERT ( SELECT application_fork FROM hafd.contexts_log WHERE id = 2 ) = 1 , 'Wrong alice1 app fork';
    ASSERT ( SELECT head_fork_id FROM hafd.contexts_log WHERE id = 2 ) = 1 , 'Wrong alice1 head fork';
    ASSERT ( SELECT head_block FROM hafd.contexts_log WHERE id = 2 ) = 50 , 'Wrong alice1 head block';
END;
$BODY$;